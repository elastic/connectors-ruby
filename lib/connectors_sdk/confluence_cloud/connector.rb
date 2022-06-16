#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'base64'
require 'connectors_sdk/atlassian/config'
require 'connectors_sdk/confluence_cloud/extractor'
require 'connectors_sdk/confluence_cloud/authorization'
require 'connectors_sdk/confluence_cloud/custom_client'
require 'connectors_sdk/base/connector'

module ConnectorsSdk
  module ConfluenceCloud
    class Connector < ConnectorsSdk::Base::Connector
      SERVICE_TYPE = 'confluence_cloud'

      def compare_secrets(params)
        missing_secrets?(params)

        {
          :equivalent => params[:secret] == params[:other_secret]
        }
      end

      def display_name
        'Confluence Cloud'
      end

      def configurable_fields
        [
          {
            'key' => 'base_url',
            'label' => 'Confluence Cloud Base URL'
          },
          {
            'key' => 'confluence_user_email',
            'label' => 'Confluence user email'
          },
          {
            'key' => 'confluence_api_token',
            'label' => 'Confluence user REST API Token'
          },
        ]
      end

      private

      def extractor_class
        ConnectorsSdk::ConfluenceCloud::Extractor
      end

      def authorization
        ConnectorsSdk::ConfluenceCloud::Authorization
      end

      def client(params)
        ConnectorsSdk::ConfluenceCloud::CustomClient.new(
          :base_url => extract_base_url(params),
          :basic_auth_token => extract_basic_auth_token(params)
        )
      end

      def custom_client_error
        ConnectorsSdk::Atlassian::CustomClient::ClientError
      end

      def config(params)
        ConnectorsSdk::Atlassian::Config.new(
          :base_url => extract_base_url(params),
          :cursors => params.fetch(:cursors, {}) || {},
          :index_permissions => params[:index_permissions] || false
        )
      end

      def health_check(params)
        client(params).me
      end

      def base_url(cloud_id)
        "https://api.atlassian.com/ex/confluence/#{cloud_id}"
      end

      private

      def is_basic_auth(params)
        login = params.fetch('confluence_user_email', nil)
        api_token = params.fetch('confluence_api_token', nil)
        login.present? && api_token.present?
      end

      def extract_basic_auth_token(params)
        login = params.fetch('confluence_user_email', nil)
        api_token = params.fetch('confluence_api_token', nil)
        nil unless login.present? && api_token.present?
        Base64.strict_encode64("#{login}:#{api_token}")
      end

      def extract_base_url(params)
        # From Confluence API documentation:
        # Requests that use OAuth 2.0 (3LO) are made via api.atlassian.com (not https://your-domain.atlassian.net).
        if is_basic_auth(params)
          return add_wiki_path(params[:base_url])
        end
        add_wiki_path(base_url(params[:cloud_id]))
      end

      def add_wiki_path(url)
        return url if url.end_with?('/wiki')
        "#{url}/wiki"
      end
    end
  end
end
