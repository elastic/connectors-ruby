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
        @pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: 5,
          max_queue: 100,
          idletime: 10,
          fallback_policy: :abort
        )
        @scheduler = Core::NativeScheduler.new(POLL_IDLING)

        start_polling_jobs!
      end

      def shutdown!
        Utility::Logger.info("Shutting down connector service with pool [#{@pool.class}] and scheduler [#{@scheduler.class}]...")
        running.make_false
        @scheduler.shutdown
        @pool.shutdown
        @pool.wait_for_termination(TERMINATION_TIMEOUT)
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
        @scheduler ||= Core::NativeScheduler.new(POLL_IDLING)
      end

      def start_polling_jobs!
        @scheduler.when_triggered do |connector_settings|
          puts("Triggered")
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

          @pool.post do
            send_heartbeat(connector_id, service_type)
            Utility::Logger.info("Starting a job for connector (ID: #{connector_id}, service type: #{service_type})...")
            job_runner = Core::SyncJobRunner.new(connector_settings, service_type)
            job_runner.execute
            GC.start
          rescue StandardError => e
            Utility::ExceptionTracking.log_exception(e, "Job for connector (ID: #{connector_id}, service type: #{service_type}) failed due to unexpected error.")
          end
          Utility::Logger.info("End of sync after thread")

          puts GC.stat
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'connector service failed due to unexpected error.')
      end

      def send_heartbeat(connector_id, service_type)
        Utility::Logger.info("Sending a heartbeat on [#{connector_id} - #{service_type}]...")
        Core::Heartbeat.send(connector_id, service_type)
      end
    end
  end
end
