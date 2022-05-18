#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/office365/config'
require 'connectors_sdk/share_point/extractor'
require 'connectors_sdk/share_point/authorization'

module ConnectorsSdk
  module SharePoint
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'share_point'

      def compare_secrets(params)
        missing_secrets?(params)

        previous_user = client(:access_token => params[:other_secret][:access_token]).me
        equivalent = previous_user.nil? ? false : previous_user.id == client(:access_token => params[:secret][:access_token]).me&.id

        {
          :equivalent => equivalent
        }
      end

      def display_name
        'SharePoint Online'
      end

      def connection_requires_redirect
        true
      end

      def configurable_fields
        [
          {
            'key' => 'client_id',
            'label' => 'Client ID'
          },
          {
            'key' => 'client_secret',
            'label' => 'Client Secret'
          },
        ]
      end

      private

      def extractor_class
        ConnectorsSdk::SharePoint::Extractor
      end

      def authorization
        ConnectorsSdk::SharePoint::Authorization
      end

      def client(params)
        ConnectorsSdk::Office365::CustomClient.new(:access_token => params[:access_token], :cursors => params.fetch(:cursors, {}) || {})
      end

      def custom_client_error
        ConnectorsSdk::Office365::CustomClient::ClientError
      end

      def config(params)
        ConnectorsSdk::Office365::Config.new(
          :cursors => params.fetch(:cursors, {}) || {},
          :drive_ids => 'all',
          :index_permissions => params[:index_permissions] || false
        )
      end

      def health_check(params)
        client(params).me
      end
    end
  end
end
