#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module ConnectorsSdk
  module Base
    class Factory
      attr_reader :connectors

      def initialize
        @connectors = {}
      end

      def register(name, klass)
        @connectors[name] = klass
      end

      def connector_class(name)
        @connectors[name]
      end
    end

    REGISTRY = Factory.new

    # loading plugins (might replace this with a directory scan and conventions on names)
    require_relative '../share_point/http_call_wrapper'
    require_relative '../confluence_cloud//http_call_wrapper'

    REGISTRY.register(ConnectorsSdk::SharePoint::HttpCallWrapper::SERVICE_TYPE, ConnectorsSdk::SharePoint::HttpCallWrapper)
    REGISTRY.register(ConnectorsSdk::ConfluenceCloud::HttpCallWrapper::SERVICE_TYPE, ConnectorsSdk::ConfluenceCloud::HttpCallWrapper)
  end
end
