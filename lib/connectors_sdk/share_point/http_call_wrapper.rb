#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/config'
require 'connectors_sdk/share_point/extractor'
require 'connectors_sdk/share_point/authorization'
require 'connectors_sdk/base/http_call_wrapper'

module ConnectorsSdk
  module SharePoint
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'share_point'

      def name
        'SharePoint'
      end

      def service_type
        SERVICE_TYPE
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
