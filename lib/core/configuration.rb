#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'utility/logger'

module Core
  class Configuration
    class << self

      def update(connector_settings, service_type = nil)
        if connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
          connector_class = Connectors::REGISTRY.connector_class(connector_settings.service_type)
          configuration = connector_class.configurable_fields
          doc = {
            :configuration => configuration
          }

          doc[:service_type] = service_type if service_type && connector_settings.needs_service_type?

          # We want to set connector to CONFIGURED status if all configurable fields have default values
          new_connector_status = if configuration.values.all? { |setting| setting[:value].present? }
                                   Utility::Logger.debug("All connector configurable fields provided default values for #{connector_settings.formatted}.")
                                   Connectors::ConnectorStatus::CONFIGURED
                                 else
                                   Connectors::ConnectorStatus::NEEDS_CONFIGURATION
                                 end

          doc[:status] = new_connector_status
          Utility::Logger.info("Changing connector status to #{new_connector_status} for #{connector_settings.formatted}.")
          Core::ElasticConnectorActions.update_connector_fields(connector_settings.id, doc)
        end
      end
    end
  end
end
