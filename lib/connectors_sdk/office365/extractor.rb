#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/custom_client'
require 'connectors_sdk/base/extractor'

module ConnectorsSdk
  module Office365
    class Extractor < ConnectorsSdk::Base::Extractor
      DRIVE_IDS_CURSOR_KEY = 'drive_ids'.freeze

      def yield_document_changes(modified_since: nil, &block)
        drives_to_index.each do |drive|
          drive_id = drive.id
          drive_owner_name = drive.dig(:owner, :user, :displayName)
          drive_name = drive.name

          drive_id_to_delta_link = config.cursors.fetch(DRIVE_IDS_CURSOR_KEY, {})
          begin
            if start_delta_link = drive_id_to_delta_link[drive_id]
              log_debug("Starting an incremental crawl with cursor for #{service_type.classify} with drive_id: #{drive_id}")
              begin
                yield_changes(drive_id, :start_delta_link => start_delta_link, :drive_owner_name => drive_owner_name, :drive_name => drive_name, &block)
              rescue ConnectorsSdk::Office365::CustomClient::Office365InvalidCursorsError
                log_warn("Error listing changes with start_delta_link: #{start_delta_link}, falling back to full crawl")
                yield_drive_items(drive_id, :drive_owner_name => drive_owner_name, :drive_name => drive_name, &block)
              end
            elsif !modified_since.nil?
              log_debug("Starting an incremental crawl using last_modified (no cursor found) for #{service_type.classify} with drive_id: #{drive_id}")
              yield_changes(drive_id, :last_modified => modified_since, :drive_owner_name => drive_owner_name, :drive_name => drive_name, &block)
            else
              log_debug("Starting a full crawl #{service_type.classify} with drive_id: #{drive_id}")
              yield_drive_items(drive_id, :drive_owner_name => drive_owner_name, :drive_name => drive_name, &block)
            end
          rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
            log_warn("Error searching and listing drive #{drive_id}")
            capture_exception(e)
          end
        end

        nil
      end

      def yield_deleted_ids(ids)
        ids.each do |id|
          yield id unless existing_drive_item_ids.include?(id)
        end
      end

      def retrieve_latest_cursors
        delta_links_for_drive_ids = drives_to_index.map(&:id).each_with_object({}) do |drive_id, h|
          h[drive_id] = client.get_latest_delta_link(drive_id)
        rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
          log_warn("Error getting delta link for #{drive_id}")
          capture_exception(e)
          raise e
        end

        {
          DRIVE_IDS_CURSOR_KEY => delta_links_for_drive_ids
        }
      end

      def yield_permissions(source_user_id)
        permissions = [source_user_id]
        client.user_groups(source_user_id, %w(id displayName)).each do |next_group|
          # Adding "Members" suffix since that is how the item permissions endpoint return group permissions
          permissions << "#{next_group.displayName} Members"
        end

        yield permissions.uniq
      rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
        # if a user is deleted, client.user_groups will throw 404 Not Found error, saving another call to get user profile
        if e.status_code == 404
          log_warn("Could not find a user with id #{source_user_id}")
          yield []
        else
          raise
        end
      end

      def client
        @client ||= super.tap do |client|
          client.cursors = config.cursors&.fetch(DRIVE_IDS_CURSOR_KEY, {}) || {}
        end
      end

      def download(item)
        download_url = item[:download_url]
        client.download_item(download_url)
      end

      private

      def drives
        raise NotImplementedError
      end

      def drives_to_index
        @drives_to_index ||=
          if config.index_all_drives?
            drives
          else
            drives.select { |d| config.drive_ids.include?(d.id) }
          end
      end

      def existing_drive_item_ids
        @existing_drive_item_ids ||= Set.new.tap do |ids|
          drives_to_index.each do |drive|
            client.list_items(drive.id) do |item|
              ids << convert_id_to_fp_id(item.id)
            end
          end
        end
      end

      def adapter
        raise NotImplementedError
      end

      def convert_id_to_fp_id(_id)
        raise NotImplementedError
      end

      def capture_exception(office365_client_error)
        options = {
          :extra => {
            :status_code => office365_client_error.status_code,
            :endpoint => office365_client_error.endpoint
          }
        }
        ConnectorsShared::ExceptionTracking.capture_exception(office365_client_error, options)
      end

      def yield_drive_items(drive_id, drive_owner_name:, drive_name:, &block)
        client.list_items(drive_id) do |item|
          yield_single_document_change(:identifier => "Office365 change: #{item&.id} (#{Office365::Adapter::GraphItem.get_path(item)})") do
            item.drive_owner_name = drive_owner_name
            item.drive_name = drive_name
            yield_create_or_update(drive_id, item, &block)
          end
        end
      end

      def yield_correct_actions_and_converted_item(drive_id, item, &block)
        if item.deleted.nil?
          yield_create_or_update(drive_id, item, &block)
        else
          yield :delete, convert_id_to_fp_id(item.id)
        end
      end

      def yield_changes(drive_id, drive_owner_name:, drive_name:, start_delta_link: nil, last_modified: nil, &block)
        client.list_changes(:drive_id => drive_id, :start_delta_link => start_delta_link, :last_modified => last_modified) do |item|
          yield_single_document_change(:identifier => "Office365 change: #{item&.id} (#{Office365::Adapter::GraphItem.get_path(item)})") do
            item.drive_owner_name = drive_owner_name
            item.drive_name = drive_name
            yield_correct_actions_and_converted_item(drive_id, item, &block)
          end
        end
      end

      def yield_create_or_update(drive_id, item)
        item = with_permissions(drive_id, item)

        document = generate_document(item)
        download_args =
          if downloadable?(item)
            download_args_and_proc(
              id: document.fetch(:id),
              name: item.name,
              size: item[:size],
              download_args: { :download_url => item.fetch('@microsoft.graph.downloadUrl') }
            ) do |args|
              download(args)
            end
          else
            []
          end
        yield :create_or_update, document, download_args
      end

      def downloadable?(item)
        item.key?('@microsoft.graph.downloadUrl')
      end

      def generate_document(item)
        if item.file
          adapter.swiftype_document_from_file(item)
        elsif item.folder
          adapter.swiftype_document_from_folder(item)
        elsif item.package
          adapter.swiftype_document_from_package(item)
        else
          raise "Unexpected Office 365 item type for item #{item}"
        end
      end

      def with_permissions(drive_id, item)
        item = item.dup
        item.permissions = client.item_permissions(drive_id, item.id) if config.index_permissions
        item
      end
    end
  end
end
