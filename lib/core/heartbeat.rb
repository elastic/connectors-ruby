#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'concurrent'
require 'connectors/connector_status'
require 'connectors/registry'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'utility/logger'

module Core
  class Heartbeat
    INTERVAL_SECONDS = 60

    class << self
      def start_task(connector_id, service_type)
        Utility::Logger.debug("Starting heartbeat timer task for [#{connector_id} - #{service_type}] with interval #{INTERVAL_SECONDS} seconds.")

        Concurrent::TimerTask.execute(execution_interval: INTERVAL_SECONDS, run_now: true) do
          Utility::Logger.debug("Sending heartbeat for the connector [#{connector_id} - #{service_type}].")
          send(connector_id, service_type)
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Heartbeat timer encountered unexpected error.')
        end

        Utility::Logger.info("Successfully started heartbeat task for the connector [#{connector_id} - #{service_type}].")
      end

      def send(connector_id, service_type)
        connector_settings = Core::ConnectorSettings.fetch_by_id(connector_id)

        doc = {
          :last_seen => Time.now
        }

        if connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
          connector_class = Connectors::REGISTRY.connector_class(service_type)
          configuration = connector_class.configurable_fields
          doc[:service_type] = service_type
          doc[:configuration] = configuration

          # We want to set connector to CONFIGURED status if all configurable fields have default values
          new_connector_status = if configuration.values.all? { |setting| setting[:value].present? }
                                   Utility::Logger.debug("All connector configurable fields provided default values for connector #{connector_id}.")
                                   Connectors::ConnectorStatus::CONFIGURED
                                 else
                                   Connectors::ConnectorStatus::NEEDS_CONFIGURATION
                                 end

          doc[:status] = new_connector_status

          Utility::Logger.info("Heartbeat updated configuration for connector #{connector_id}.")
          Utility::Logger.info("Changing connector status to #{new_connector_status}.")
        elsif connector_settings.connector_status_allows_sync?
          connector_instance = Connectors::REGISTRY.connector(service_type, connector_settings.configuration)
          doc[:status] = connector_instance.is_healthy? ? Connectors::ConnectorStatus::CONNECTED : Connectors::ConnectorStatus::ERROR
          message = "Health check for 3d party service failed for connector [#{connector_id}], service type [#{service_type}]. Check the application logs for more information."
          doc[:error] = doc[:status] == Connectors::ConnectorStatus::ERROR ? message : nil
        end

        Core::ElasticConnectorActions.update_connector_fields(connector_id, doc)
      rescue Core::ConnectorSettings::ConnectorNotFoundError => e
        error_message = "Failed to send heartbeat for connector [#{connector_id}], service type [#{service_type}] because connector settings were not found."
        Utility::ExceptionTracking.log_exception(e, error_message)
        Core::ElasticConnectorActions.update_connector_status(connector_id, Connectors::ConnectorStatus::ERROR, error_message)
      end
    end
  end
end
