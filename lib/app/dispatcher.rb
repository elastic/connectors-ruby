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

module App
  class Dispatcher
    POLL_INTERVAL = (App::Config.poll_interval || 3).to_i
    TERMINATION_TIMEOUT = (App::Config.termination_timeout || 60).to_i
    HEARTBEAT_INTERVAL = (App::Config.heartbeat_interval || 60 * 30).to_i
    MIN_THREADS = (App::Config.dig(:thread_pool, :min_threads) || 0).to_i
    MAX_THREADS = (App::Config.dig(:thread_pool, :max_threads) || 5).to_i
    MAX_QUEUE = (App::Config.dig(:thread_pool, :max_queue) || 100).to_i

    class << self
      def start!
        Utility::Logger.info("Starting connector service in #{App::Config.native_mode ? 'native' : 'non-native'} mode...")
        start_polling_jobs!
      end

      def shutdown!
        scheduler.shutdown
      end

      private

      def scheduler
        @scheduler ||= if App::Config.native_mode
                         Core::NativeScheduler.new(POLL_INTERVAL, HEARTBEAT_INTERVAL)
                       else
                         Core::SingleScheduler.new(App::Config.connector_id, POLL_INTERVAL, HEARTBEAT_INTERVAL)
                       end
      end

      def start_polling_jobs!
        scheduler.when_triggered do |connector_settings, task|
          case task
          when :sync
            start_sync_task(connector_settings)
          when :heartbeat
            start_heartbeat_task(connector_settings)
          when :configuration
            start_configuration_task(connector_settings)
          else
            Utility::Logger.error("Unknown task type: #{task}. Skipping...")
          end
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'The connector service failed due to unexpected error.')
      end

      def start_sync_task(connector_settings)
        start_heartbeat_task(connector_settings)
        Utility::Logger.info("Starting a sync job for #{connector_settings.formatted}...")
        Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
        job_runner = Core::SyncJobRunner.new(connector_settings)
        job_runner.execute
        puts "EXECUTE DONE"
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Sync job for #{connector_settings.formatted} failed due to unexpected error.")
      end

      def start_heartbeat_task(connector_settings)
        Utility::Logger.info("Sending heartbeat for #{connector_settings.formatted}...")
        Core::Heartbeat.send(connector_settings)
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Heartbeat task for #{connector_settings.formatted} failed due to unexpected error.")
      end

      def start_configuration_task(connector_settings)
        Utility::Logger.info("Updating configuration for #{connector_settings.formatted}...")
        # when in non-native mode, populate the service type if it's not in connector settings
        service_type = if !App::Config.native_mode && connector_settings.needs_service_type?
                         App::Config.service_type
                       else
                         nil
                       end
        Core::Configuration.update(connector_settings, service_type)
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Configuration task for #{connector_settings.formatted} failed due to unexpected error.")
      end
    end
  end
end
