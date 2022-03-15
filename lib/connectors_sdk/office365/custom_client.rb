#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/custom_client'
require 'connectors_shared'
require 'hashie/mash'

module ConnectorsSdk
  module Office365
    class CustomClient < ConnectorsSdk::Base::CustomClient

      OFFICE365_PERMISSION_SYNC_TIME_SLA = 24.hours

      class ClientError < ConnectorsShared::ClientError
        attr_reader :status_code, :endpoint

        def initialize(status_code, endpoint)
          @status_code = status_code
          @endpoint = endpoint
        end
      end

      class Office365InvalidCursorsError < ClientError; end

      # This is necessary because `Faraday::NestedParamsEncoder.encode` changes the
      # order of params, which Microsoft's download API can't handle for some reason.
      module Office365DownloadParamsEncoder
        class << self
          extend Forwardable
          def_delegators :'Faraday::NestedParamsEncoder', :escape, :decode

          def encode(params)
            params.map do |key, value|
              "#{escape(key)}=#{escape(value)}"
            end.join('&')
          end
        end
      end

      attr_reader :access_token
      attr_accessor :cursors

      BASE_URL = 'https://graph.microsoft.com/v1.0/'.freeze

      def initialize(access_token:, cursors: {}, ensure_fresh_auth: nil)
        @access_token = access_token
        @cursors = cursors || {}
        super(:ensure_fresh_auth => ensure_fresh_auth)
      end

      def update_auth_data!(new_access_token)
        @access_token = new_access_token
        self
      end

      def me
        request_endpoint(:endpoint => 'me')
      end

      def one_drive_drives(fields: [])
        query_params = transform_fields_to_request_query_params(fields)
        response = request_endpoint(:endpoint => 'me/drives/', :query_params => query_params)
        response.value
      end

      def share_point_drives(fields: [])
        # When new Private Team site is created in SharePoint, permissions take some time to propagate, therefore
        # this site won't be indexed by us until propagation happens. This code tries to also fetch sites from
        # recently created groups (new Private Team site will be there) to reduce friction and index this site
        # earlier.
        # See: https://github.com/elastic/ent-search/pull/3581
        share_point_sites = (sites(:fields => %w[id]) + recent_share_point_group_sites(:fields => %[id]))

        share_point_sites
          .map(&:id)
          .uniq
          .map { |site_id| site_drives(site_id, :fields => fields) }
          .flatten
          .compact
      end

      def groups(fields: [])
        request_all(:endpoint => 'groups/', :fields => fields)
      end

      def group_root_site(group_id, fields: [])
        query_params = transform_fields_to_request_query_params(fields)

        request_endpoint(:endpoint => "groups/#{group_id}/sites/root", :query_params => query_params)
      end

      def sites(fields: [])
        # This empty search string ends up returning all sites. If we leave it off, the API returns a 400
        # I explicity set the page size here (via :top) because otherwise the API just returns the first ten and
        # does not provide any additional pages.
        request_all(:endpoint => 'sites/', :fields => fields, :additional_query_params => { :search => '', :top => 10 })
      end

      def site_drives(site_id, fields: [])
        document_libraries(
          request_all(:endpoint => "sites/#{site_id}/drives/", :fields => fields)
        )
      rescue ClientError => e
        ConnectorsShared::Logger.info("Received response of #{e.status_code} trying to get drive for Site with Id = #{site_id}: #{e.message}")
        nil
      end

      def list_items(drive_id, fields: [], break_after_page: false)
        # MSFT Graph API does not have a recursive list items, have to do this dfs style

        if break_after_page && cursors['page_cursor'].present?
          stack = cursors.delete('page_cursor')
        else
          stack = [get_root_item(drive_id, ['id']).id]
        end

        # We rely on the id field below to perform our DFS
        fields_with_id = fields.any? ? fields | ['id'] : fields
        yielded = 0
        while stack.any?
          folder_id = stack.pop
          item_children(drive_id, folder_id, :fields => fields_with_id) do |item|
            if item.folder
              stack << item.id
            end
            yield item

            yielded += 1
          end

          if break_after_page && yielded >= 100
            cursors['page_cursor'] = stack.dup
            break
          end
        end
      end

      def item_permissions(drive_id, item_id)
        request_endpoint(:endpoint => "drives/#{drive_id}/items/#{item_id}/permissions").value
      end

      def list_changes(drive_id:, start_delta_link: nil, last_modified: nil, break_after_page: false)
        query_params = { :'$select' => %w(id content.downloadUrl lastModifiedDateTime lastModifiedBy root deleted file folder package name webUrl createdBy createdDateTime size).join(',') }
        response =
          if break_after_page && cursors['page_cursor'].present?
            request_json(:url => cursors.delete('page_cursor'))
          elsif start_delta_link.nil?
            endpoint = "drives/#{drive_id}/root/delta"
            request_endpoint(:endpoint => endpoint, :query_params => query_params)
          else
            request_json(:url => start_delta_link, :query_params => query_params)
          end

        yielded = 0
        loop do
          response.value.each do |change|
            # MSFT Graph API does not allow us to view "changes" in chronological order, so if there is no cursor,
            # we have to iterate through all changes and cherry-pick the ones that are past the `last_modified` Time
            # since to get another cursor, we would have to go through all the changes anyway
            next if last_modified.present? && Time.parse(change.lastModifiedDateTime) < last_modified
            next if change.root # We don't want to index the root of the drive

            yield change
            yielded += 1
          end

          if break_after_page && yielded >= 100 && response['@odata.nextLink'].present?
            cursors['page_cursor'] = response['@odata.nextLink']
            break
          end

          break if response['@odata.nextLink'].nil?
          response = request_json(:url => response['@odata.nextLink'])
        end

        cursors[drive_id] = response['@odata.deltaLink']
      end

      def get_latest_delta_link(drive_id)
        cursors[drive_id] || exhaustively_get_delta_link(drive_id)
      end

      def exhaustively_get_delta_link(drive_id)
        endpoint = "drives/#{drive_id}/root/delta"

        Connectors::Stats.measure('custom_client.office365.exhaustively_get_delta_link') do
          response = request_endpoint(:endpoint => endpoint, :query_params => { :'$select' => 'id' })

          while next_link = response['@odata.nextLink']
            response = request_json(:url => next_link)
          end

          response['@odata.deltaLink'].split('?').first
        end
      end

      def download_item(download_url)
        request(:url => download_url) do |request|
          request.options.params_encoder = Office365DownloadParamsEncoder
        end.body
      end

      def user_groups(user_id, fields = [])
        (
          request_all(
            :endpoint => "users/#{user_id}/transitiveMemberOf",
            :fields => fields
          ) +
            request_all(
              :endpoint => "users/#{user_id}/ownedObjects",
              :fields => fields
            ).select { |next_object| next_object['@odata.type'] == '#microsoft.graph.group' }
        ).uniq
      end

      private

      def recent_share_point_group_sites(fields: [])
        # group.createdDateTime field is UTC as stated in documentation:
        # https://docs.microsoft.com/en-us/graph/api/resources/group?view=graph-rest-1.0#properties
        created_date_time_threshold = Time.now.utc - OFFICE365_PERMISSION_SYNC_TIME_SLA

        groups(:fields => %w(id createdDateTime))
          .select { |group| group.createdDateTime > created_date_time_threshold }
          .map { |group| group_root_site(group.id, :fields => %w[id]) }.compact
      end

      def document_libraries(drives)
        drives.select { |drive| drive.driveType == 'documentLibrary' }
      end

      def transform_fields_to_request_query_params(fields = [])
        fields.empty? ? {} : { :'$select' => fields.join(',') }
      end

      def request_all(endpoint:, fields: [], additional_query_params: {})
        query_params = transform_fields_to_request_query_params(fields)
        response = request_endpoint(:endpoint => endpoint, :query_params => query_params.merge(additional_query_params))

        items = response.value
        while next_link = response['@odata.nextLink']
          response = request_json(:url => next_link)
          items.concat(response.value)
        end
        items
      end

      def get_root_item(drive_id, fields = [])
        query_params = transform_fields_to_request_query_params(fields)
        request_endpoint(:endpoint => "drives/#{drive_id}/root", :query_params => query_params)
      end

      def item_children(drive_id, item_id, fields: [], &block)
        endpoint = "drives/#{drive_id}/items/#{item_id}/children"
        query_params = transform_fields_to_request_query_params(fields)
        response = request_endpoint(:endpoint => endpoint, :query_params => query_params)

        loop do
          response.value.each(&block)
          next_link = response['@odata.nextLink']
          break if next_link.nil?
          response = request_json(:url => next_link)
        end
      end

      def base_headers
        {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        }
      end

      def raise_any_errors(response, url:, query_params: {})
        if HTTP::Status.successful?(response.status)
          response
        else
          response_body = response.body.to_s
          error_message = begin
            error = JSON.parse(response_body).fetch('error')
            if error['code'] == 'resyncRequired'
              Connectors::Stats.increment('custom_client.office365.error.invalid_cursors')
              raise Office365InvalidCursorsError.new(response.status, url)
            end
            JSON.parse(error.fetch('message')).fetch('Message').strip
          rescue ClientError
            raise
          rescue StandardError
            "got a #{response.status} from #{url} with query #{query_params}"
          end
          raise ClientError.new(response.status, url), error_message
        end
      end

      def request_endpoint(endpoint:, query_params: nil)
        url = "#{BASE_URL}#{endpoint}"
        request_json(:url => url, :query_params => query_params)
      end

      def request_json(url:, query_params: nil)
        response = request(:url => url, :query_params => query_params, :headers => base_headers)
        Hashie::Mash.new(JSON.parse(response.body))
      end

      def request(url:, query_params: nil, headers: nil, &block)
        raise_any_errors(
          get(url, query_params, headers, &block),
          :url => url,
          :query_params => query_params
        )
      end
    end
  end
end
