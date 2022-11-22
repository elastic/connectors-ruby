#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'
require 'utility/constants'
require 'core/connector_job'
require 'core/sync_job_runner'
require 'concurrent'

module Core
  module Jobs
    class Consumer
      def initialize(scheduler:,
                     max_ingestion_queue_size:,
                     max_ingestion_queue_bytes:,
                     poll_interval: 3,
                     termination_timeout: 60,
                     min_threads: 1,
                     max_threads: 5,
                     max_queue: 100,
                     idle_time: 5)
        @scheduler = scheduler
        @poll_interval = poll_interval
        @termination_timeout = termination_timeout
        @min_threads = min_threads
        @max_threads = max_threads
        @max_queue = max_queue
        @idle_time = idle_time

        @max_ingestion_queue_size = max_ingestion_queue_size
        @max_ingestion_queue_bytes = max_ingestion_queue_bytes
      end

      def subscribe!(index_name:)
        Utility::Logger.info("Starting a new consumer for #{@index_name} index")

        @index_name = index_name
        start_timer_task!
        start_thread_pool!
      end

      def running?
        pool&.running? && timer_task&.running?
      end

      def shutdown!
        Utility::Logger.info("Shutting down consumer for #{@index_name} index")

        timer_task.shutdown
        pool.shutdown
        pool.wait_for_termination(@termination_timeout)
        reset_pool!
      end

      private

      attr_reader :pool, :timer_task

      def start_timer_task!
        @timer_task = Concurrent::TimerTask.execute(execution_interval: @poll_interval, run_now: true) { execute }
      end

      def start_thread_pool!
        @pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: @min_threads,
          max_threads: @max_threads,
          max_queue: @max_queue,
          fallback_policy: :abort,
          idletime: @idle_time
        )
      end

      def reset_pool!
        @pool = nil
      end

      def execute
        Utility::Logger.debug('Getting registered connectors')

        connectors = ready_for_sync_connectors
        return unless connectors.any?

        Utility::Logger.debug("Number of available connectors: #{connectors.size}")

        # @TODO It is assumed that @index_name is used to retrive pending jobs.
        # This will be discussed after 8.6 release
        pending_jobs = Core::ConnectorJob.pending_jobs(connectors_ids: connectors.keys)
        Utility::Logger.info("Number of pending jobs: #{pending_jobs.size}")

        pending_jobs.each do |job|
          connector_settings = connectors[job.connector_id]
          execute_job(job, connector_settings)
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'The consumer group failed')
      end

      def execute_job(job, connector_settings)
        pool.post do
          Utility::Logger.info("Connector #{connector_settings.formatted} picked up the job #{job.id}")
          Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
          job_runner = Core::SyncJobRunner.new(
            connector_settings,
            job,
            @max_ingestion_queue_size,
            @max_ingestion_queue_bytes
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

      def ready_for_sync_connectors
        @scheduler.connector_settings
          .select(&:ready_for_sync?)
          .inject({}) { |memo, cs| memo.merge(cs.id => cs) }
      end
    end
  end
end
