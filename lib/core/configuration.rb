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
        if connector_settings.needs_configuration?
          connector_class = Connectors::REGISTRY.connector_class(connector_settings.service_type || service_type)

          unless connector_class
            Utility::Logger.error("Couldn't find connector for service type #{connector_settings.service_type || service_type}")
            return
          end

          features = connector_class.kibana_features.each_with_object({}) { |feature, hsh| hsh[feature] = true }
          configurable_fields = connector_class.configurable_fields_indifferent_access
          doc = {
            :features => features
          }

          doc[:service_type] = service_type if service_type && connector_settings.needs_service_type?

          if configurable_fields_defaults_present?(configurable_fields, connector_settings)
            doc[:configuration] = configurable_fields
            doc[:status] = Connectors::ConnectorStatus::CONFIGURED
          elsif configuration_fully_set?(connector_settings)
            # We don't want to override the existing fully set configuration with default values
            doc[:status] = Connectors::ConnectorStatus::CONFIGURED
          else
            doc[:status] = Connectors::ConnectorStatus::NEEDS_CONFIGURATION
          end

          Utility::Logger.info("Changing connector status to #{doc[:status]} for #{connector_settings.formatted}.")
          Core::ElasticConnectorActions.update_connector_fields(connector_settings.id, doc)
        end
      end

      private

      def configurable_fields_defaults_present?(configurable_fields, connector_settings)
        if configurable_fields.values.all? { |setting| setting[:value].present? }
          Utility::Logger.debug("All connector configurable fields provided default values for #{connector_settings.formatted}.")
          return true
        end

        false
      end

      def configuration_fully_set?(connector_settings)
        if connector_settings.configuration.with_indifferent_access.values.all? { |setting| setting[:value].present? }
          Utility::Logger.debug("All connector configurable fields were set for #{connector_settings.formatted}.")
          return true
        end

        false
      end
    end
  end
end
