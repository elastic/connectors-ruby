#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/registry'
require 'utility'

module App
  class ListConnectors
    def self.run!
      Utility::Environment.set_execution_environment(App::Config) do
        Utility::Logger.info('Registered connectors:')
        Connectors::REGISTRY.registered_connectors.each do |connector|
          Utility::Logger.info("- #{Connectors::REGISTRY.connector_class(connector).display_name}")
        end
        Utility::Logger.info('Bye')
      end
    end
  end
end
