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
require 'connectors_sdk/base/http_call_wrapper'

module ConnectorsSdk
  module ConfluenceCloud
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'confluence_cloud'

      def name
        'Confluence Cloud'
      end

      def service_type
        SERVICE_TYPE
      end

      private

      def extractor_class
        ConnectorsSdk::ConfluenceCloud::Extractor
      end

      def authorization
        ConnectorsSdk::ConfluenceCloud::Authorization
      end

      def client(params)
        ConnectorsSdk::ConfluenceCloud::CustomClient.new(:base_url => base_url(params[:cloud_id]), :access_token => params[:access_token])
      end

      def custom_client_error
        ConnectorsSdk::Atlassian::CustomClient::ClientError
      end

      def config(params)
        ConnectorsSdk::Atlassian::Config.new(:base_url => base_url(params[:cloud_id]), :cursors => params.fetch(:cursors, {}) || {})
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
