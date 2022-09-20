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

    def connector(name, configuration)
      klass = connector_class(name)
      if klass.present?
        return klass.new(configuration: configuration)
      end
      raise "Connector #{name} is not yet registered. You need to register it before use"
    end

    def registered_connectors
      @connectors.keys.sort
    end
  end

  REGISTRY = Factory.new

  require_relative 'mongodb/connector'
  REGISTRY.register(Connectors::MongoDB::Connector.service_type, Connectors::MongoDB::Connector)
end
