#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'concurrent-ruby'
require 'connectors'
require 'core'
require 'utility'
require 'app/config'

module App
  class Dispatcher
    POLL_IDLING = (App::Config[:idle_timeout] || 60).to_i
    TERMINATION_TIMEOUT = (App::Config[:termination_timeout] || 60).to_i
    MIN_THREADS = (App::Config.thread_pool&.min_threads || 0).to_i
    MAX_THREADS = (App::Config.thread_pool&.max_threads || 5).to_i
    MAX_QUEUE = (App::Config.thread_pool&.max_queue || 100).to_i

    @running = Concurrent::AtomicBoolean.new(false)

    class << self
      def start!
        running!
        Utility::Logger.info('Starting connector service...')
        start_heartbeat_task!
        start_configuration_task!
        start_polling_jobs!
      end

      def shutdown!
        Utility::Logger.info("Shutting down connector service with pool [#{pool.class}]...")
        running.make_false
        sync_scheduler.shutdown
        heartbeat_scheduler.shutdown
        configuration_scheduler.shutdown
        pool.shutdown
        pool.wait_for_termination(TERMINATION_TIMEOUT)
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

      def sync_scheduler
        @sync_scheduler ||= Core::NativeScheduler.new(:sync, POLL_IDLING)
      end

      def heartbeat_scheduler
        @heartbeat_scheduler ||= Core::NativeScheduler.new(:heartbeat, POLL_IDLING)
      end

      def configuration_scheduler
        @configuration_scheduler ||= Core::NativeScheduler.new(:configuration, 5)
      end

      def start_polling_jobs!
        Utility::Logger.info('Start polling jobs...')
        sync_scheduler.when_triggered do |connector_settings|
          service_type = connector_settings.service_type
          connector_id = connector_settings.id
          index_name = connector_settings.index_name

          # connector-level checks
          unless Connectors::REGISTRY.registered?(service_type)
            Utility::Logger.info("The service type (#{service_type}) of connector (ID: #{connector_id}) is not supported. Skipping...")
            next
          end
          if index_name.nil? || index_name.empty?
            Utility::Logger.info("The index name of connector (ID: #{connector_id}, service type: #{service_type}) is empty. Skipping...")
            next
          end
          unless index_name.start_with?(Utility::Constants::CONTENT_INDEX_PREFIX)
            Utility::Logger.info("The index name of connector (ID: #{connector_id}, service type: #{service_type}) is invalid, it must start with '#{Utility::Constants::CONTENT_INDEX_PREFIX}'. Skipping...")
            next
          end
          Core::ElasticConnectorActions.ensure_content_index_exists(index_name)

          pool.post do
            Utility::Logger.info("Starting a job for connector (ID: #{connector_id}, service type: #{service_type})...")
            job_runner = Core::SyncJobRunner.new(connector_settings, service_type)
            job_runner.execute
          rescue StandardError => e
            Utility::ExceptionTracking.log_exception(e, "Job for connector (ID: #{connector_id}, service type: #{service_type}) failed due to unexpected error.")
          end
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'connector service failed due to unexpected error.')
      end

      def start_heartbeat_task!
        Thread.new do
          Utility::Logger.info('Start heartbeat task...')
          heartbeat_scheduler.when_triggered do |connector_settings|
            pool.post do
              service_type = connector_settings.service_type
              connector_id = connector_settings.id
              Utility::Logger.info("Sending a heartbeat for connector (ID: #{connector_id}, service type: #{service_type})...")
              Core::Heartbeat.send(connector_id, service_type)
            rescue StandardError => e
              Utility::ExceptionTracking.log_exception(e, "Heartbeat task for connector (ID: #{connector_id}, service type: #{service_type}) failed due to unexpected error.")
            end
          rescue StandardError => e
            Utility::ExceptionTracking.log_exception(e, 'connector service failed due to unexpected error.')
          end
        end
      end

      def start_configuration_task!
        Thread.new do
          Utility::Logger.info('Start configuration task...')
          configuration_scheduler.when_triggered do |connector_settings|
            pool.post do
              Utility::Logger.info("Updating configuration for connector (ID: #{connector_settings.id}, service type: #{connector_settings.service_type})...")
              Core::Configuration.update(connector_settings)
            rescue StandardError => e
              Utility::ExceptionTracking.log_exception(e, "Configuration task for connector (ID: #{connector_id}, service type: #{service_type}) failed due to unexpected error.")
            end
          end
        end
      end
    end
  end
end
