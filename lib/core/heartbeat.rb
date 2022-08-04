#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'concurrent'
require 'connectors/connector_status'
require 'connectors/registry'
require 'core/elastic_connector_actions'
require 'utility/logger'

module Core
  class Heartbeat
    class << self
      def start_task(connector_id, service_type)
        interval_seconds = 60 # seconds
        Utility::Logger.debug("Starting heartbeat timer task with interval #{interval_seconds} seconds.")
        task = Concurrent::TimerTask.new(execution_interval: interval_seconds, run_now: true) do
          Utility::Logger.debug("Sending heartbeat for the connector #{connector_id}")
          send(connector_id, service_type)
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Heartbeat timer encountered unexpected error.')
        end

        Utility::Logger.info('Successfully started heartbeat task.')

        task.execute
      end

      private

      def send(connector_id, service_type)
        connector_settings = Core::ConnectorSettings.fetch(connector_id)

        doc = {
          :last_seen => Time.now
        }

        if connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
          connector_class = Connectors::REGISTRY.connector_class(service_type)
          configuration = connector_class.configurable_fields
          doc[:configuration] = configuration

          # We want to set connector to CONFIGURED status if all configurable fields have default values
          new_connector_status = if configuration.values.all? { |setting| setting[:value] }
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
          doc[:status] = connector_instance.source_status[:status] == 'OK' ? Connectors::ConnectorStatus::CONNECTED : Connectors::ConnectorStatus::ERROR
        end

        ElasticConnectorActions.update_connector_fields(connector_id, doc)
      end
    end
  end
end
