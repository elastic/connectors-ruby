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
  class Consumer
    POLL_INTERVAL = (App::Config.poll_interval || 3).to_i
    TERMINATION_TIMEOUT = (App::Config.termination_timeout || 60).to_i
    HEARTBEAT_INTERVAL = (App::Config.heartbeat_interval || 60 * 30).to_i
    MIN_THREADS = (App::Config.dig(:thread_pool, :min_threads) || 0).to_i
    MAX_THREADS = (App::Config.dig(:thread_pool, :max_threads) || 5).to_i
    MAX_QUEUE = (App::Config.dig(:thread_pool, :max_queue) || 100).to_i
    JOB_CLEANUP_INTERVAL = (App::Config.job_cleanup_interval || 60 * 5).to_i

    @running = Concurrent::AtomicBoolean.new(false)

    class << self
      def start!
        Utility::Logger.info("Starting connector service in #{App::Config.native_mode ? 'native' : 'non-native'} mode...")
        start_consumer!
      end

      def shutdown!
        Utility::Logger.info("Shutting down connector service...")
        stop_consumer!
      end

      private

      attr_reader :running


      def scheduler
        @scheduler ||= if App::Config.native_mode
                         Core::NativeScheduler.new(POLL_INTERVAL, HEARTBEAT_INTERVAL)
                       else
                         Core::SingleScheduler.new(App::Config.connector_id, POLL_INTERVAL, HEARTBEAT_INTERVAL)
                       end
      end

      def start_consumer!
        @consumer = Core::Jobs::Consumer.new(
          poll_interval: POLL_INTERVAL,
          termination_timeout: TERMINATION_TIMEOUT,
          min_threads: MIN_THREADS,
          max_threads: MAX_THREADS,
          max_queue: MAX_QUEUE,
          max_ingestion_queue_size: (App::Config.max_ingestion_queue_size || Utility::Constants::DEFAULT_MAX_INGESTION_QUEUE_SIZE).to_i,
          max_ingestion_queue_bytes: (App::Config.max_ingestion_queue_bytes || Utility::Constants::DEFAULT_MAX_INGESTION_QUEUE_BYTES).to_i,
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
