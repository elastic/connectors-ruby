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

      def name
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
          {
            :action => :create_or_update,
            :document => ConnectorsSdk::GitLab::Adapter.to_es_document(:project, doc.with_indifferent_access),
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
        []
      end

      def permissions(_params)
        []
      end
    end
  end
end
