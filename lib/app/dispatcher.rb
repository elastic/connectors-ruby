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

    attr_reader :scheduler

    def initialize
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 5,
        max_threads: 10,
        max_queue: 100,
        fallback_policy: :abort
      )
      @is_shutting_down = false
      @heartbeats = {}
    end

    def start!
      @scheduler ||= Core::NativeScheduler.new(POLL_IDLING)
      @scheduler.when_triggered do |connector_settings|
        service_type = connector_settings.service_type
        connector_id = connector_settings.id

        # connector-level checks
        Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
        raise "[#{service_type}] is not a supported connector" unless Connectors::REGISTRY.registered?(service_type)

        @pool.post do
          send_heartbeat(connector_id, service_type)
          Utility::Logger.info("Starting a job for [#{service_type} - #{connector_id}]...")
          job_runner = Core::SyncJobRunner.new(connector_settings, service_type)
          job_runner.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, "Job for [#{service_type} - #{connector_id}] failed due to unexpected error.")
        end
      end
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, 'Dispatcher failed due to unexpected error.')
    end

    def shutdown
      Utility::Logger.info("Shutting down dispatcher with pool [#{@pool&.class}] and scheduler [#{@scheduler&.class}]...")
      @is_shutting_down = true
      @scheduler&.shutdown
      @pool.shutdown
      @pool.wait_for_termination(TERMINATION_TIMEOUT)
    end

    private

    def send_heartbeat(connector_id, service_type)
      Utility::Logger.info("Sending a heartbeat on [#{connector_id} - #{service_type}]...")
      Core::Heartbeat.send(connector_id, service_type)
    end

    def self.run_dispatcher!
      # Dispatcher is responsible for dispatching connectors to workers.
      Utility::Logger.info('Starting dispatcher...')
      dispatcher = App::Dispatcher.new
      dispatcher.start!
    end
  end
end
