#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/gitlab_connector/config'
require 'connectors_sdk/gitlab_connector/custom_client'

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
            'key' => 'bearer_token',
            'label' => 'Bearer Token'
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
        response = client.get(:user)
        response.present? && response.status == 200
      end

      def document_batch(_params)
        query_params = {
          :simple => 1,
          :pagination => :keyset,
          :per_page => 100, # max
          :order_by => :id,
          :sort => :desc
        }
        results_list = get_json(_params, :url => :projects, :query_params => query_params)
        # for now let's just take one page
        [ { :results => results_list } , {}, true]
      end

      def deleted(_params)
        []
      end

      def permissions(_params)
        []
      end

      def get_json(_params, url:, query_params: nil, &block)
        response = client(_params).get(url.to_s, { :params => query_params }, &block)
        Hashie::Array.new(JSON.parse(response.body))
      end
    end
  end
end
