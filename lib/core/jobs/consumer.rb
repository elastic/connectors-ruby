
#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module Jobs
    class Consumer
      POLL_INTERVAL = (App::Config.poll_interval || 3).to_i
      TERMINATION_TIMEOUT = (App::Config.termination_timeout || 60).to_i
      MIN_THREADS = (App::Config.dig(:thread_pool, :min_threads) || 0).to_i
      MAX_THREADS = (App::Config.dig(:thread_pool, :max_threads) || 5).to_i
      MAX_QUEUE = (App::Config.dig(:thread_pool, :max_queue) || 100).to_i
      IDLE_TIME = (App::Config.dig(:thread_pool, :idle_time) || 5).to_i

      def initialize
        @running = Concurrent::AtomicBoolean.new(false)

        Kernel.at_exit { shutdown! }
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
        Utility::Logger.info("Shutting down the Consumer for #{@index_name} index")
        @running.make_false
        pool.shutdown
        pool.wait_for_termination(TERMINATION_TIMEOUT)
      end

      private

      def start_loop!
        Utility::Logger.info("Starting a Consumer for #{@index_name} index")

        Thread.new do
          # assign a name to the thread
          # see @TODO in #running?
          Thread.current[:name] = "consumer-group-#{@index_name}"

          loop do
            if @running.false?
              Utility::Logger.info('Shutting down the loop')
              break
            end

            sleep(POLL_INTERVAL)
            Utility::Logger.info('Getting registered connectors')

            # load active connectors settings
            connectors = ready_for_sync_connectors

            next unless connectors.any?

            Utility::Logger.info("Number of available connectors: #{connectors.size}")
            pending_jobs = Core::ConnectorJob.pending_jobs(connectors_ids: connectors.keys)

            # @TODO check if Connector is in_progress state
            Utility::Logger.info("Number of available jobs: #{pending_jobs.size}")

            pending_jobs.each do |job|
              connector_settings = connectors[job.connector_id]

              pool.post do
                Utility::Logger.info("Initiating a sync job for #{connector_settings.formatted}...")
                Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
                job_runner = Core::SyncJobRunner.new(connector_settings, job)
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
          min_threads: MIN_THREADS,
          max_threads: MAX_THREADS,
          max_queue: MAX_QUEUE,
          fallback_policy: :abort,
          idletime: IDLE_TIME
        )
      end

      # @TODO replace it with the direct API call
      def scheduler
        App::Dispatcher.send(:scheduler)
      end

      def ready_for_sync_connectors
        scheduler.connector_settings
          .select(&:ready_for_sync?)
          .inject({}) { |memo, cs| memo.merge(cs.id => cs) }
      end
    end
  end
end
