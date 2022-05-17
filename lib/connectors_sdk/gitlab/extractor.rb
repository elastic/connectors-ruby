#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/extractor'
require 'connectors_sdk/gitlab/custom_client'
require 'connectors_sdk/gitlab/adapter'
require 'connectors_sdk/gitlab/config'
require 'rack/utils'

module ConnectorsSdk
  module GitLab
    class Extractor < ConnectorsSdk::Base::Extractor
      PAGE_SIZE = 100 # max is 100

      def yield_document_changes(modified_since: nil)
        query_params = {
          :pagination => :keyset,
          :per_page => PAGE_SIZE,
          :order_by => :id,
          :sort => :desc
        }
        # # looks like it's an incremental sync
        if modified_since.present?
          date_since = modified_since.is_a?(Time) ? modified_since : Time.new(modified_since)
          query_params[:last_activity_after] = date_since.iso8601
        end

        next_page_link = nil

        loop do
          if next_page_link.present?
            if (matcher = /(https?:[^>]*)/.match(next_page_link))
              clean_query = URI.parse(matcher.captures[0]).query
              query_params = Rack::Utils.parse_query(clean_query)
            else
              raise "Next page link has unexpected format: #{next_page_link}"
            end
          end
          response = client.get('projects', query_params)

          JSON.parse(response.body).map do |doc|
            doc = doc.with_indifferent_access
            if config.index_permissions
              doc = doc.merge(project_permissions(doc[:id], doc[:visibility]))
            end
            yield :create_or_update, ConnectorsSdk::GitLab::Adapter.to_es_document(:project, doc), nil
          end

          next_page_link = response.headers['Link'] || nil
          break unless next_page_link.present?
        end
      end

      def yield_deleted_ids(ids)
        if ids.present?
          ids.each do |id|
            response = client.get("projects/#{id}")
            if response.status == 404
              # not found - assume deleted
              yield id
            else
              unless response.success?
                raise "Could not get a project by ID: #{id}, response code: #{response.status}, response: #{response.body}"
              end
            end
          end
        end
      end

      def yield_permissions(source_user_id)
        result = []
        if source_user_id.present?
          result.push("user:#{source_user_id}")

          user_response = client.get("users/#{source_user_id}")
          if user_response.success?
            username = JSON.parse(user_response.body).with_indifferent_access[:username]
            query = { :external => true, :username => username }
            external_response = client.get('users', query)
            if external_response.success?
              external_users = Hashie::Array.new(JSON.parse(external_response.body))
              if external_users.empty?
                # the user is not external
                result.push('type:internal')
              end
            else
              raise "Could not check external user status by ID: #{source_user_id}"
            end
          else
            raise "User isn't found by ID: #{source_user_id}"
          end
        end
        yield result
      end

      private

      def project_permissions(id, visibility)
        result = []
        if visibility.to_sym == :public || !config.index_permissions
          # visible-to-all
          return {}
        end
        if visibility.to_sym == :internal
          result.push('type:internal')
        end
        response = client.get("projects/#{id}/members/all")
        if response.success?
          members = Hashie::Array.new(JSON.parse(response.body))
          result.concat(members.map { |user| "user:#{user[:id]}" })
        else
          raise "Could not get project members by project ID: #{id}, response code: #{response.status}, response: #{response.body}"
        end
        { :_allow_permissions => result }
      end
    end
  end
end
