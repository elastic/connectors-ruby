#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'core'
require 'utility'
require 'app/config'
require 'concurrent'

module App
  module Worker
    POLL_IDLING = (App::Config['idle_timeout'] || 60).to_i

    class << self
      def start!
        pre_flight_check

        Utility::Logger.info('Starting to process jobs...')
        start_heartbeat_task
        start_polling_jobs
      end

      private

      def pre_flight_check
        raise "#{App::Config['service_type']} is not a supported connector" unless Connectors::REGISTRY.registered?(App::Config['service_type'])
        Core::ElasticConnectorActions.ensure_connectors_index_exists
        Core::ElasticConnectorActions.ensure_job_index_exists
        connector_settings = Core::ConnectorSettings.fetch(App::Config[:connector_id])
        Core::ElasticConnectorActions.ensure_content_index_exists(
          connector_settings.index_name,
          App::Config[:use_analysis_icu],
          App::Config[:content_language_code]
        )
      end

      def start_heartbeat_task
        connector_id = App::Config[:connector_id]
        interval_seconds = 60 # seconds
        Utility::Logger.debug("Starting heartbeat timer task with interval #{interval_seconds} seconds.")
        task = Concurrent::TimerTask.new(execution_interval: interval_seconds) do
          Utility::Logger.debug("Sending heartbeat for the connector #{connector_id}")
          Core::ElasticConnectorActions.heartbeat(connector_id)
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Heartbeat timer encountered unexpected error.')
        end

        task.execute
      end

      def start_polling_jobs
        loop do
          job_runner = create_sync_job_runner
          job_runner.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
        ensure
          if POLL_IDLING > 0
            Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds")
            sleep(POLL_IDLING)
          end
        end
      end

      def create_sync_job_runner
        connector_settings = Core::ConnectorSettings.fetch(App::Config[:connector_id])

        Core::SyncJobRunner.new(connector_settings, App::Config['service_type'])
      end
    end
  end
end
