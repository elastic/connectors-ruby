#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'framework'
require 'utility'

module App
  module Connector
    POLL_IDLING = 60

    @client = Utility::EsClient.new

    class << self
      def start!
        pre_flight_check

        Utility::Logger.info('Starting to process jobs...')
        start_polling_jobs
      end

      def create_connector(index_name)
        connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])

        if connector_settings.nil?
          Framework::ElasticConnectorActions.ensure_index_exists(Framework::ElasticConnectorActions::CONNECTORS_INDEX)
          Framework::ElasticConnectorActions.create_connector(index_name)

          connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])
        end

        connector_settings.id
      end

      private

      def pre_flight_check
        raise "#{App::Config['service_type']} is not a supported connector" unless Connectors::REGISTRY.registered?(App::Config['service_type'])
      end

      def start_polling_jobs
        loop do
          job_runner = create_sync_job_runner

          job_runner.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
        ensure
          Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds")
          sleep(POLL_IDLING)
        end
      end

      def create_sync_job_runner
        connector_instance = Connectors::REGISTRY.connector_class(App::Config['service_type']).new
        connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])

        connector_settings.update_configuration(connector_instance.configurable_fields) unless connector_settings.configuration_initialized?

        Framework::SyncJobRunner.new(
          connector_settings: connector_settings,
          connector_instance: connector_instance
        )
      end
    end
  end
end
