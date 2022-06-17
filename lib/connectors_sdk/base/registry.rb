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

    require_relative '../stub_connector/connector'
    REGISTRY.register(ConnectorsSdk::StubConnector::Connector::SERVICE_TYPE, ConnectorsSdk::StubConnector::Connector)

    # loading plugins (might replace this with a directory scan and conventions on names)
    require_relative '../gitlab/connector'

    REGISTRY.register(ConnectorsSdk::GitLab::Connector::SERVICE_TYPE, ConnectorsSdk::GitLab::Connector)
  end
end
