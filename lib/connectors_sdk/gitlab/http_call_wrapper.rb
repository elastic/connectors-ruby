#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/gitlab/custom_client'
require 'connectors_sdk/gitlab/adapter'
require 'rack/utils'

module ConnectorsSdk
  module GitLab
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'gitlab'

      def display_name
        'GitLab Connector'
      end

      def configurable_fields
        [
          {
            'key' => 'api_token',
            'label' => 'API Token'
          },
          {
            'key' => 'base_url',
            'label' => 'Base URL'
          }
        ]
      end

      def client(params)
        ConnectorsSdk::GitLab::CustomClient.new(
          :base_url => params[:base_url] || ConnectorsSdk::GitLab::API_BASE_URL,
          :api_token => params[:api_token]
        )
      end

      def health_check(_params)
        # let's do a simple call
        response = client(_params).get('user')
        response.present? && response.status == 200
      end

      def document_batch(_params)
        query_params = {
          :simple => true,
          :pagination => :keyset,
          :per_page => 100, # max
          :order_by => :id,
          :sort => :desc
        }
        cursors = _params[:cursors]
        next_cursors = {}

        if cursors.present? && cursors[:next_page].present?
          if (matcher = /(https?:[^>]*)/.match(cursors[:next_page]))
            clean_query = URI.parse(matcher.captures[0]).query
            query_params = Rack::Utils.parse_query(clean_query)
          else
            raise "Next page link has unexpected format: #{cursors}"
          end
        end

        # looks like it's an incremental sync
        if cursors.present? && cursors[:modified_since].present?
          query_params[:last_activity_after] = Time.parse(cursors[:modified_since].to_s).iso8601
          next_cursors[:modified_since] = cursors[:modified_since]
        end

        response = client(_params).get('projects', query_params)

        results_list = JSON.parse(response.body).map do |doc|
          doc = doc.with_indifferent_access
          if _params[:index_permissions]
            doc = doc.merge(project_permissions(_params, doc[:id], doc[:visibility]))
          end
          {
            :action => :create_or_update,
            :document => ConnectorsSdk::GitLab::Adapter.to_es_document(:project, doc),
            :download => nil
          }
        end

        next_page = response.headers['Link'] || ""

        # paging is defined by what came in the next_page
        [
          Hashie::Array.new(results_list),
          next_page.empty? ? next_cursors : next_cursors.merge({ :next_page => next_page }),
          next_page.empty? # we're saying it's the last page
        ]
      end

      def deleted(_params)
        result = []
        if _params[:ids].present?
          _params[:ids].each do |id|
            response = client(_params).get("projects/#{id}")
            if response.status == 404
              # not found - assume deleted
              result.push(id)
            else
              unless response.success?
                raise "Could not get a project by ID: #{id}, response code: #{response.status}, response: #{response.body}"
              end
            end
          end
        end
        result
      end

      def permissions(_params)
        result = []
        if _params[:user_id].present?
          id = _params[:user_id]

          result.push("user:#{id.to_s}")
          client = client(_params)

          user_response = client.get("users/#{id}")
          if user_response.success?
            username = JSON.parse(user_response.body).with_indifferent_access[:username]
            external_response = client.get("users", { :external => true, :username => username })
            if external_response.success?
              external_users = Hashie::Array.new(JSON.parse(external_response.body))
              if external_users.size == 0
                # the user is not external
                result.push('type:internal')
              end
            else
              raise "Could not check external user status by ID: #{id}"
            end
          else
            raise "User isn't found by ID: #{id}"
          end
        end
        result
      end

      private

      def project_permissions(_params, id, visibility)
        result = []
        if visibility.to_sym == :public || !(_params[:index_permissions] || false)
          # visible-to-all
          return {}
        end
        if visibility.to_sym == :internal
          result.push('type:internal')
        end
        response = client(_params).get("projects/#{id}/members/all")
        if response.success?
          members = Hashie::Array.new(JSON.parse(response.body))
          result = result.concat(members.map { |user| "user:#{user[:id]}" })
        else
          raise "Could not get project members by project ID: #{id}, response code: #{response.status}, response: #{response.body}"
        end
        { :_allow_permissions => result }
      end
    end
  end
end
