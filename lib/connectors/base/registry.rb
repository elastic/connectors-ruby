#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Connectors
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

      def connector(name, params = nil)
        connector_class = connector_class(name)
        if connector_class.present?
          return params.present? ? connector_class.new(params) : connector_class.new
        end
        raise "Connector #{name} is not yet registered. You need to register it before use"
      end

      def registered_connectors
        @connectors.keys.sort
      end
    end

    REGISTRY = Factory.new

    require_relative '../stub_connector/connector'
    REGISTRY.register(Connectors::StubConnector::Connector::SERVICE_TYPE, Connectors::StubConnector::Connector)

    # loading plugins (might replace this with a directory scan and conventions on names)
    require_relative '../gitlab/connector'

    REGISTRY.register(Connectors::GitLab::Connector::SERVICE_TYPE, Connectors::GitLab::Connector)
  end
end
