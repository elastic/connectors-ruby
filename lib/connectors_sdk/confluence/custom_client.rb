#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/atlassian/custom_client'

module ConnectorsSdk
  module Confluence
    class CustomClient < ConnectorsSdk::Atlassian::CustomClient
      SEARCH_ENDPOINT = 'rest/api/search'
      CONTENT_SEARCH_ENDPOINT = 'rest/api/content/search'
      CONTENT_EXPAND_FIELDS = %w(body.export_view history.lastUpdated ancestors space children.comment.body.export_view container).freeze

      def content(space:, types: [], start_at: 0, order_field_and_direction: 'created asc', updated_after: nil, next_value: nil)
        search_helper(
          :endpoint => CONTENT_SEARCH_ENDPOINT,
          :space => space,
          :types => types,
          :start_at => start_at,
          :order_field_and_direction => order_field_and_direction,
          :updated_after => updated_after,
          :next_value => next_value
        )
      end

      def content_by_id(content_id, include_permissions: false, expand_fields: CONTENT_EXPAND_FIELDS)
        endpoint = "rest/api/content/#{Faraday::Utils.escape(content_id)}"
        if include_permissions
          expand_fields = expand_fields.dup
          expand_fields << 'restrictions.read.restrictions.user'
          expand_fields << 'restrictions.read.restrictions.group'
        end
        response = begin
          parse_and_raise_if_necessary!(get(endpoint, :status => 'any', :expand => expand_fields.join(',')))
        rescue ContentConvertibleError
          # Confluence has a bug when trying to expand `container` for certain items:
          # https://jira.atlassian.com/browse/CONFSERVER-40475
          Connectors::Stats.increment('custom_client.confluence.error.content_convertible')
          parse_and_raise_if_necessary!(get(endpoint, :status => 'any', :expand => (expand_fields - ['container']).join(',')))
        end
        Hashie::Mash.new(response)
      end

      def spaces(start_at: 0, limit: 50, space_keys: nil, include_permissions: false)
        params = {
          :start => start_at,
          :limit => limit
        }
        params[:spaceKey] = space_keys if space_keys.present?
        params[:expand] = 'permissions' if include_permissions
        response = get('rest/api/space', params)
        Hashie::Mash.new(parse_and_raise_if_necessary!(response))
      end

      def search(
        space: nil,
        start_at: 0,
        limit: 50,
        types: [],
        expand_fields: [],
        order_field_and_direction: 'created asc',
        updated_after: nil
      )
        search_helper(
          :endpoint => SEARCH_ENDPOINT,
          :space => space,
          :start_at => start_at,
          :limit => limit,
          :types => types,
          :expand_fields => expand_fields,
          :order_field_and_direction => order_field_and_direction,
          :updated_after => updated_after
        )
      end

      def content_search(cql, expand: [], limit: 25)
        response = get(CONTENT_SEARCH_ENDPOINT, :cql => cql, :expand => expand.join(','), :limit => limit)
        Hashie::Mash.new(parse_and_raise_if_necessary!(response))
      end

      def me
        response = get('rest/api/user/current')
        Hashie::Mash.new(parse_and_raise_if_necessary!(response))
      end

      private

      def search_helper(
        endpoint:,
        space: nil,
        start_at: 0,
        limit: 50,
        types: [],
        expand_fields: [],
        order_field_and_direction: 'created asc',
        updated_after: nil,
        next_value: nil
      )

        response =
          if next_value.present?
            get(next_value.reverse.chomp('/').reverse)
          else
            params = {
              :cql => generate_cql(:space => space, :types => types, :order_field_and_direction => order_field_and_direction, :updated_after => updated_after),
              :start => start_at,
              :expand => expand_fields.join(','),
              :limit => limit
            }

            get(endpoint, params)
          end

        Hashie::Mash.new(parse_and_raise_if_necessary!(response))
      end

      def generate_cql(space: nil, types: nil, order_field_and_direction: nil, updated_after: nil)
        query_conditions = []
        query_conditions << "space=\"#{space}\"" if space
        query_conditions << "type in (#{types.join(',')})" if types.any?
        query_conditions << "lastmodified > \"#{format_date(updated_after)}\"" if updated_after.present?

        query_parts = [query_conditions.join(' AND ')]
        query_parts << "order by #{order_field_and_direction}" if order_field_and_direction

        query_parts.join(' ').strip
      end

      def format_date(date)
        DateTime.parse(date).strftime('%Y-%m-%d %H:%M')
      end
    end
  end
end
