#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'active_support/core_ext/class/subclasses'
require 'connectors'

module Connectors
  class Registry
    class << self
      def registered?(name)
        connectors.has_key?(name)
      end

      def connector_class(name)
        connectors[name]
      end

      def connector(name, configuration)
        klass = connector_class(name)
        if klass.present?
          return klass.new(configuration: configuration)
        end
        raise "Connector #{name} is not yet registered. You need to register it before use"
      end

      def registered_connectors
        connectors.keys.sort
      end

      private

      def connectors
        @connectors ||= load_connectors
      end

      def load_connectors
        connectors = {}
        connectors_in_yaml = App::Config.connectors.dup || []
        Utility::Logger.debug("connectors_in_yaml: #{connectors_in_yaml}")
        return connectors if connectors_in_yaml.empty?
        Connectors::Base::Connector.subclasses.each do |klass|
          if connectors_in_yaml.include?(klass.service_type)
            Utility::Logger.debug("Add #{klass.service_type} as registered connector.")
            connectors[klass.service_type] = klass
            connectors_in_yaml.delete(klass.service_type)
          end
        end
        Utility::Logger.warn("Couldn't find connectors for #{connectors_in_yaml.join(', ')}.") if connectors_in_yaml.any?
        connectors
      end
    end
  end
end
