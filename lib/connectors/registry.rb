#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Connectors
  class Factory
    attr_reader :connectors

    def initialize
      @connectors = {}
    end

    def register(name, klass)
      @connectors[name] = klass
    end

    def registered?(name)
      @connectors.has_key?(name)
    end

    def connector_class(name)
      @connectors[name]
    end

    def connector(name, remote_configuration)
      klass = connector_class(name)
      if klass.present?
        local_configuration = App::Config[name]
        return klass.new(
          local_configuration: local_configuration,
          remote_configuration: remote_configuration
        )
      end
      raise "Connector #{name} is not yet registered. You need to register it before use"
    end

    def registered_connectors
      @connectors.keys.sort
    end
  end

  REGISTRY = Factory.new

  require_relative './stub_connector/connector'
  REGISTRY.register(Connectors::StubConnector::Connector.service_type, Connectors::StubConnector::Connector)

  # loading plugins (might replace this with a directory scan and conventions on names)
  require_relative './gitlab/connector'

  REGISTRY.register(Connectors::GitLab::Connector.service_type, Connectors::GitLab::Connector)

  require_relative 'mongodb/connector'
  REGISTRY.register(Connectors::MongoDB::Connector.service_type, Connectors::MongoDB::Connector)
end
