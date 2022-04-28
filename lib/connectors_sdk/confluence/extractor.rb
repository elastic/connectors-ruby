#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/atlassian/custom_client'
require 'connectors_sdk/confluence/adapter'
require 'connectors_sdk/base/extractor'

module ConnectorsSdk
  module Confluence
    class Extractor < ConnectorsSdk::Base::Extractor
      CONTENT_OFFSET_CURSOR_KEY = 'content'
      CONTENT_NEXT_CURSOR_KEY = 'next'
      CONTENT_MODIFIED_SINCE_NEXT_CURSOR_KEY = 'modified_since_next'
      CONTENT_MODIFIED_SINCE_CURSOR_KEY = 'content_modified_at'

      ConnectorsSdk::Base::Extractor::TRANSIENT_SERVER_ERROR_CLASSES << Atlassian::CustomClient::ServiceUnavailableError

      def yield_document_changes(modified_since: nil, break_after_page: false)
        @space_permissions_cache = {}
        @content_restriction_cache = {}
        yield_spaces do |space|
          yield_single_document_change(:identifier => "Confluence Space: #{space&.fetch(:key)} (#{space&.webui})") do
            permissions = config.index_permissions ? get_space_permissions(space) : []
            yield :create_or_update, Confluence::Adapter.swiftype_document_from_confluence_space(space, content_base_url, permissions)
          end

          yield_content_for_space(
            :space => space[:key],
            :types => %w(page blogpost attachment),
            :modified_since => modified_since
          ) do |content|
            restrictions = config.index_permissions ? get_content_restrictions(content) : []
            if content.type == 'attachment'
              document = Confluence::Adapter.swiftype_document_from_confluence_attachment(content, content_base_url, restrictions)
              download_args = download_args_and_proc(
                id: document.fetch(:id),
                name: content.title,
                size: content.extensions.fileSize,
                download_args: { content: content }
              ) do |args|
                download(args)
              end
              yield :create_or_update, document, download_args
            else
              yield :create_or_update, Confluence::Adapter.swiftype_document_from_confluence_content(content, content_base_url, restrictions)
            end
          end

          if break_after_page
            @completed = true
            break
          end
        end
      end

      def yield_deleted_ids(ids)
        id_groups = ids.group_by do |id|
          if Confluence::Adapter.fp_id_is_confluence_space_id?(id)
            :space
          elsif Confluence::Adapter.fp_id_is_confluence_content_id?(id)
            :content
          elsif Confluence::Adapter.fp_id_is_confluence_attachment_id?(id)
            :attachment
          else
            :unknown
          end
        end

        %i(space content attachment).each do |group|
          confluence_ids = Array(id_groups[group]).map { |id| Confluence::Adapter.public_send("fp_id_to_confluence_#{group}_id", id) }
          get_ids_for_deleted(confluence_ids, group).each do |deleted_id|
            yield Confluence::Adapter.public_send("confluence_#{group}_id_to_fp_id", deleted_id)
          end
        end
      end

      def download(item)
        content = item[:content]
        client.download("#{content._links.base}#{content._links.download}").body
      end

      private

      def content_base_url
        'https://workplace-search.atlassian.net/wiki'
      end

      def yield_spaces
        @space_cursor ||= 0
        loop do
          response = client.spaces(:start_at => @space_cursor, :include_permissions => config.index_permissions)
          response.results.each do |space|
            yield space
            @space_cursor += 1
          end
          break unless should_continue_looping?(response)
          log_info("Requesting more spaces with cursor: #{@space_cursor}")
        end
      end

      def yield_content_for_space(space:, types:, modified_since:)
        loop do
          response = client.content(
            :space => space,
            :types => types,
            :order_field_and_direction => modified_since ? 'lastmodified asc' : 'created asc',
            cursoring_param(:modified_since => modified_since, :space => space) => cursoring_value(:modified_since => modified_since, :space => space)
          )

          response.results.each do |result|
            yield_single_document_change(:identifier => "Confluence ID: #{result&.id} (#{result&.webui})") do
              content = client.content_by_id(result.id, :include_permissions => config.index_permissions)
              yield content if content.status == 'current'
            end
          end
          update_content_cursors(space, response, modified_since)

          break unless should_continue_looping?(response)
          log_info("Requesting more content for space #{space} with cursor: #{cursoring_param(:modified_since => modified_since, :space => space)} #{cursoring_value(:modified_since => modified_since, :space => space)}")
        end
      end

      def next_cursor_key(modified_since:)
        modified_since ? CONTENT_MODIFIED_SINCE_NEXT_CURSOR_KEY : CONTENT_NEXT_CURSOR_KEY
      end

      def cursoring_param(modified_since:, space:)
        return :next_value if config.cursors.dig(next_cursor_key(:modified_since => modified_since), space).present?

        modified_since ? :updated_after : :start_at
      end

      def cursoring_value(modified_since:, space:)
        next_value = config.cursors.dig(next_cursor_key(:modified_since => modified_since), space)
        return next_value if next_value.present?

        get_content_cursors(space, modified_since)[space]
      end

      def update_content_cursors(space, response, modified_since)
        if response._links&.next.present?
          config.cursors[next_cursor_key(:modified_since => modified_since)] ||= {}
          config.cursors[next_cursor_key(:modified_since => modified_since)][space] = response._links.next
        end

        if response.results && modified_since
          updated_cursor = response.results.last&.history&.lastUpdated&.when
          config.cursors[CONTENT_MODIFIED_SINCE_CURSOR_KEY][space] = updated_cursor if updated_cursor
        else
          config.cursors[CONTENT_OFFSET_CURSOR_KEY][space] += response.results.size
        end
      end

      def get_content_cursors(space, modified_since)
        modified_since ? get_content_modified_since_cursors(space, modified_since) : get_content_offset_cursors(space)
      end

      def get_content_offset_cursors(space)
        config.cursors[CONTENT_OFFSET_CURSOR_KEY] ||= {}
        config.cursors[CONTENT_OFFSET_CURSOR_KEY][space] ||= 0
        config.cursors[CONTENT_OFFSET_CURSOR_KEY]
      end

      def get_content_modified_since_cursors(space, modified_since)
        config.cursors[CONTENT_MODIFIED_SINCE_CURSOR_KEY] ||= {}
        config.cursors[CONTENT_MODIFIED_SINCE_CURSOR_KEY][space] ||= modified_since.to_s
        config.cursors[CONTENT_MODIFIED_SINCE_CURSOR_KEY]
      end

      def should_continue_looping?(response)
        response.results&.size.to_i > 0 && response._links.next.present?
      end

      def get_ids_for_deleted(search_ids, group)
        return [] if search_ids.empty?

        response, id_sym =
          if group == :space
            [client.spaces(:space_keys => search_ids, :limit => search_ids.size), :key]
          else
            [client.content_search("id in (#{search_ids.join(',')})", :limit => search_ids.size), :id]
          end
        found_ids = response.results.map { |result| result.fetch(id_sym) }.map(&:to_s)
        search_ids - found_ids
      end

      def get_space_permissions(space)
        space_permissions = space.permissions&.select { |permission| %w(read administer).include?(permission.operation.operation) }
        if space_permissions.nil? || space_permissions.any?(&:anonymousAccess)
          @space_permissions_cache[space.fetch('key')] = []
          return []
        end

        subjects = space_permissions.flat_map(&:subjects)
        permissions = [
          subjects.select { |subject| subject.has_key?(:user) }.map { |subject| subject.user.results.map { |user| "user:#{user.accountId}" } },
          subjects.select { |subject| subject.has_key?(:group) }.map { |subject| subject.group.results.map { |group| "group:#{group.name}" } }
        ].flatten.uniq
        @space_permissions_cache[space.fetch('key')] = permissions
      end

      def get_user_spaces(user_id)
        (@space_permissions_cache || {}).select { |_, permissions| "user:#{user_id}".in?(permissions) }.keys.uniq
      end

      def get_group_spaces(group_name)
        (@space_permissions_cache || {}).select { |_, permissions| "group:#{group_name}".in?(permissions) }.keys.uniq
      end

      # get_content_restrictions returns the final restriction of the content, taking into consideration inherited restrictions
      # if the content is an attachment, the final restriction will will be either space permissions
      # or (in case they aren't empty) the intersection of
      #  1. its restriction
      #  2. its container's restriction
      #  3. its container's ancestors' restriction
      # if the content is a page or blog post, the final restriction will be either space permissions
      # or (in case they aren't empty) the intersection of
      #  1. its restrictions
      #  2. its ancestors' restrictions
      def get_content_restrictions(content)
        restrictions = []
        restrictions << extract_restrictions(content.restrictions&.read&.restrictions)

        # space permissions should always be available in cache
        space_key = content.space&.fetch('key')
        space_restrictions = (@space_permissions_cache[space_key] || [])

        ancestors = content.ancestors || []

        if content.type == 'attachment'
          if content.container&.type == 'global'
            log_info("Skipping ancestor restrictions as it is a space and should already be cached: [#{content.id}] in [#{content.container&.type}_#{content.container&.id}]")
          else
            container = client.content_by_id(content.container&.id, :include_permissions => true)
            @content_restriction_cache[container.id] ||= extract_restrictions(container.restrictions&.read&.restrictions)
            restrictions << @content_restriction_cache[container.id]
            ancestors = container.ancestors
          end
        end

        ancestors.each do |ancestor|
          restrictions << get_restrictions_by_content_id(ancestor.id)
        end

        combined_restrictions = restrictions.select(&:any?).reduce(:&)
        @content_restriction_cache[content.id] = combined_restrictions || []
        (combined_restrictions || space_restrictions).map { |restriction| "#{space_key}/#{restriction}" }
      end

      def get_restrictions_by_content_id(content_id)
        @content_restriction_cache[content_id] ||= begin
          content = client.content_by_id(content_id, :include_permissions => true)
          extract_restrictions(content.restrictions&.read&.restrictions)
        end
      end

      def extract_restrictions(restrictions)
        [
          restrictions&.user&.results&.map { |user| "user:#{user.accountId}" },
          restrictions&.group&.results&.map { |group| "group:#{group.name}" }
        ].flatten.compact.uniq
      end
    end
  end
end
