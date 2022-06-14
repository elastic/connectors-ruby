#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

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
            'label' => 'Base URL'
          },
          {
            'key' => 'basic_auth_token',
            'label' => 'basic_auth_token'
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
          :base_url => base_url(params[:cloud_id]),
          :basic_auth_token => params[:basic_auth_token]
        )
      end

      def custom_client_error
        ConnectorsSdk::Atlassian::CustomClient::ClientError
      end

      def config(params)
        ConnectorsSdk::Atlassian::Config.new(
          :base_url => "#{params[:external_connector_base_url]}/wiki",
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
    end
  end
end
