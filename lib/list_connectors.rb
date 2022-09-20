#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/config'
require 'connectors/registry'
require 'utility'

class ListConnectors
  def self.run!
    Utility::Environment.set_execution_environment(App::Config) do
      registered_connectors = Connectors::Registry.registered_connectors
      if registered_connectors.empty?
        Utility::Logger.info('There\'s no registered connector.')
      else
        Utility::Logger.info('Registered connectors:')
        registered_connectors.each do |connector|
          Utility::Logger.info("- #{Connectors::Registry.connector_class(connector).display_name}")
        end
        Utility::Logger.info('Bye')
      end
    end
  end
end
