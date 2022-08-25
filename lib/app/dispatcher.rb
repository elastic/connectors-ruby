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

    attr_reader :is_shutting_down

    def initialize
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 5,
        max_threads: 10,
        max_queue: 100,
        fallback_policy: :abort
      )
      @is_shutting_down = false
    end

    def start!
      # TODO need to do pre-flight and start a single heartbeat task for dispatcher
      @scheduler = Core::NativeScheduler.new(POLL_IDLING).when_triggered do |connector_settings|
        @pool.post do
          job_runner = Core::SyncJobRunner.new(connector_settings, connector_settings[:service_type])
          job_runner.execute
        end
      end
    rescue SystemExit
      puts 'Exiting.'
    rescue Interrupt
      shutdown
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, 'Dispatcher failed due to unexpected error.')
    end

    def shutdown
      Utility::Logger.info("Shutting down #{@pool.scheduled_task_count} scheduled tasks...")
      @is_shutting_down = true
      @scheduler&.shutdown
      @pool.shutdown
      @pool.wait_for_termination(TERMINATION_TIMEOUT)
    end
  end

  def run_dispatcher!
    # Dispatcher is responsible for dispatching connectors to workers.
    Utility::Logger.info('Starting dispatcher...')
    Utility::Environment.set_execution_environment(App::Config) do
      dispatcher = App::Dispatcher.new
      dispatcher.start!
    end
  end
end
