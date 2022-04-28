#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/confluence/extractor'

module ConnectorsSdk
  module ConfluenceCloud
    class Extractor < ConnectorsSdk::Confluence::Extractor

      def yield_permissions(source_user_id)
        # yield empty permissions if the user is suspended or deleted
        user = client.user(source_user_id, :expand => 'operations')
        if user.nil? || user.operations.blank?
          yield [] and return
        end

        # refresh space permissions if not initialized
        if @space_permissions_cache.nil?
          @space_permissions_cache = {}
          yield_spaces do |space|
            if config.index_permissions
              get_space_permissions(space)
            end
          end
        end

        direct_spaces = get_user_spaces(source_user_id)
        indirect_spaces = []

        group_permissions = []
        client.user_groups(source_user_id).each do |group|
          group_name = group.name
          group_spaces = get_group_spaces(group_name)
          indirect_spaces << group_spaces
          group_permissions << "group:#{group_name}"
        end

        total_user_spaces = indirect_spaces.flatten.concat(direct_spaces).uniq
        user_permissions = ["user:#{source_user_id}"]
          .concat(group_permissions)
          .product(total_user_spaces)
          .collect { |permission, space| "#{space}/#{permission}" }

        yield user_permissions.flatten.uniq.sort
      end

      def download(item)
        content = item[:content]
        parent_id = content.dig('container', 'id')
        client.download("#{client.base_url}/wiki/rest/api/content/#{parent_id}/child/attachment/#{content['id']}/download").body
      end
    end
  end
end
