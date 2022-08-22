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

    attr_reader :workers

    def initialize
      @workers = {}.with_indifferent_access
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 5,
        max_threads: 10,
        max_queue: 100,
        fallback_policy: :caller_runs
      )
      @is_shutting_down = false
    end

    def start!
      if App::Config['mode'] == 'dispatcher'
        loop do
          connectors = Core::ElasticConnectorActions.native_connectors
          if connectors.empty?
            Utility::Logger.info('No native connectors found.')
            return
          end
          Utility::Logger.info("Total workers: #{workers.size}. Checking if all native connectors are running...")
          connectors.each do |connector|
            if !workers[connector[:id]].nil?
              Utility::Logger.info("Connector #{connector[:id]} for service type #{connector[:service_type]} is running.")
            else
              worker = App::Worker.new(
                connector_id: connector[:id],
                service_type: connector[:service_type],
                is_native: true
              )
              @workers[connector[:id]] = worker
              @pool.post do
                Utility::Logger.info("Starting #{connector[:id]} for service type #{connector[:service_type]}... Total workers: #{@workers.count}")
                worker.start!
              end
            end
          end
          if @is_shutting_down
            break
          end
        ensure
          if POLL_IDLING > 0
            Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds.")
            sleep(POLL_IDLING)
          end
        end
      else
        message = 'Worker mode set for the application. Please check your configuration.'
        Utility::Logger.error(message)
        exit
      end
    rescue SystemExit
      puts 'Exiting.'
    rescue Interrupt
      shutdown
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, 'Dispatcher failed due to unexpected error.')
    end

    def shutdown
      Utility::Logger.info("Shutting down #{workers.size} workers...")
      @is_shutting_down = true
      @pool.shutdown
      @pool.wait_for_termination(TERMINATION_TIMEOUT)
    end
  end
end
