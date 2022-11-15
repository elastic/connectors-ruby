#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'concurrent'
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

    @running = Concurrent::AtomicBoolean.new(false)

    class << self
      def start!
        running!
        Utility::Logger.info("Starting connector service in #{App::Config.native_mode ? 'native' : 'non-native'} mode...")

        # start sync jobs consumer
        start_consumer!

        start_polling_jobs!
      end

      def shutdown!
        Utility::Logger.info("Shutting down connector service with pool [#{pool.class}]...")
        running.make_false
        scheduler.shutdown
        pool.shutdown
        pool.wait_for_termination(TERMINATION_TIMEOUT)

        stop_consumer!
      end

      private

      attr_reader :running

      def running!
        raise 'connector service is already running!' unless running.make_true
      end

      def pool
        @pool ||= Concurrent::ThreadPoolExecutor.new(
          min_threads: MIN_THREADS,
          max_threads: MAX_THREADS,
          max_queue: MAX_QUEUE,
          fallback_policy: :abort
        )
      end

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
            # update connector sync_now flag
            Core::ElasticConnectorActions.update_connector_sync_now(connector_settings.id, false)

            Core::Jobs::Producer.enqueue_job(job_type: :sync, connector_settings: connector_settings)
          when :heartbeat
            start_heartbeat_task(connector_settings)
          when :configuration
            start_configuration_task(connector_settings)
          when :filter_validation
            start_filter_validation_task(connector_settings)
          else
            Utility::Logger.error("Unknown task type: #{task}. Skipping...")
          end
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'The connector service failed due to unexpected error.')
      end

      def start_sync_task(connector_settings)
        start_heartbeat_task(connector_settings)
        pool.post do
          Utility::Logger.info("Initiating a sync job for #{connector_settings.formatted}...")
          Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
          job_runner = Core::SyncJobRunner.new(
            connector_settings,
            (App::Config.max_ingestion_queue_size || Utility::Constants::DEFAULT_MAX_INGESTION_QUEUE_SIZE).to_i,
            (App::Config.max_ingestion_queue_bytes || Utility::Constants::DEFAULT_MAX_INGESTION_QUEUE_BYTES).to_i
          )
          job_runner.execute
        rescue Core::JobAlreadyRunningError
          Utility::Logger.info("Sync job for #{connector_settings.formatted} is already running, skipping.")
        rescue Core::ConnectorVersionChangedError => e
          Utility::Logger.info("Could not start the job because #{connector_settings.formatted} has been updated externally. Message: #{e.message}")
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, "Sync job for #{connector_settings.formatted} failed due to unexpected error.")
        end
      end

      def start_heartbeat_task(connector_settings)
        pool.post do
          Utility::Logger.info("Sending heartbeat for #{connector_settings.formatted}...")
          Core::Heartbeat.send(connector_settings)
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, "Heartbeat task for #{connector_settings.formatted} failed due to unexpected error.")
        end
      end

      def start_configuration_task(connector_settings)
        pool.post do
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

      def start_filter_validation_task(connector_settings)
        pool.post do
          Utility::Logger.info("Validating filters for #{connector_settings.formatted}...")
          validation_job_runner = Core::Filtering::ValidationJobRunner.new(connector_settings)
          validation_job_runner.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, "Filter validation task for #{connector_settings.formatted} failed due to unexpected error.")
        end
      end

      def start_consumer!
        @consumer = Core::Jobs::Consumer.new(
          poll_interval: POLL_INTERVAL,
          termination_timeout: TERMINATION_TIMEOUT,
          min_threads: MIN_THREADS,
          max_threads: MAX_THREADS,
          max_queue: MAX_QUEUE,
          scheduler: scheduler
        )

        @consumer.subscribe!(index_name: Utility::Constants::JOB_INDEX)
      end

      def stop_consumer!
        return if @consumer.nil?
        return unless @consumer.running?

        @consumer.shutdown!
      end
    end
  end
end
