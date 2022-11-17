#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/constants'

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

        @running = Concurrent::AtomicBoolean.new(false)
      end

      def subscribe!(index_name:)
        @index_name = index_name

        start_loop!
      end

      def running?
        # @TODO check if a loop thread is alive
        pool.running? && @running.true?
      end

      def shutdown!
        Utility::Logger.info("Shutting down consumer for #{@index_name} index")
        @running.make_false
        pool.shutdown
        pool.wait_for_termination(@termination_timeout)
        # reset pool
        @pool = nil
      end

      private

      def start_loop!
        Utility::Logger.info("Starting a new consumer for #{@index_name} index")

        Thread.new do
          # assign a name to the thread
          # see @TODO in #self.running?
          Thread.current[:name] = "consumer-group-#{@index_name}"

          loop do
            if @running.false?
              Utility::Logger.info('Shutting down the loop')
              break
            end

            sleep(@poll_interval)
            Utility::Logger.debug('Getting registered connectors')

            connectors = ready_for_sync_connectors
            next unless connectors.any?

            Utility::Logger.debug("Number of available connectors: #{connectors.size}")

            # @TODO It is assumed that @index_name is used to retrive pending jobs.
            # This will be discussed after 8.6 release
            pending_jobs = Core::ConnectorJob.pending_jobs(connectors_ids: connectors.keys)
            Utility::Logger.info("Number of pending jobs: #{pending_jobs.size}")

            pending_jobs.each do |job|
              connector_settings = connectors[job.connector_id]

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
          rescue StandardError => e
            Utility::ExceptionTracking.log_exception(e, 'The consumer group failed')
          end
        end

        @running.make_true
      end

      def pool
        @pool ||= Concurrent::ThreadPoolExecutor.new(
          min_threads: @min_threads,
          max_threads: @max_threads,
          max_queue: @max_queue,
          fallback_policy: :abort,
          idletime: @idle_time
        )
      end

      def ready_for_sync_connectors
        @scheduler.connector_settings
          .select(&:ready_for_sync?)
          .inject({}) { |memo, cs| memo.merge(cs.id => cs) }
      end
    end
  end
end
