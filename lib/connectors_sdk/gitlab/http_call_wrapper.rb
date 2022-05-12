#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/gitlab/custom_client'
require 'connectors_sdk/gitlab/adapter'
require 'connectors_sdk/gitlab/config'
require 'connectors_sdk/gitlab/extractor'
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

      def config(params)
        ConnectorsSdk::GitLab::Config.new(
          :cursors => params.fetch(:cursors, {}) || {},
          :index_permissions => params.fetch(:index_permissions, {}) || false
        )
      end

      def health_check(params)
        # let's do a simple call
        response = client(params).get('user')
        response.present? && response.status == 200
      end

      def custom_client_error
        ConnectorsSdk::GitLab::CustomClient::ClientError
      end

      private

      def extractor_class
        ConnectorsSdk::GitLab::Extractor
      end
    end
  end
end
