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
    attr_reader :workers

    def initialize
      @workers = []
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 5,
        max_threads: 10,
        max_queue: 100,
        fallback_policy: :caller_runs
      )
    end

    def self.run!
      if App::Config['mode'] == 'dispatcher'
        native_connectors = Core::ElasticConnectorActions.get_native_connectors
        if native_connectors.empty?
          Utility::Logger.info('No native connectors found.')
          return
        end
        native_connectors.each do |connector|
          Utility::Logger.info('Starting native connectors.')
          @pool.post do
            worker = App::Worker.new(
              connector_id: connector.id,
              service_type: connector.service_type,
              is_native: true)
            worker.start!
            @workers << worker
          end
        end
      else
        Utility::Logger.error('Worker mode set for the application. Please check your configuration.')
      end
    end

    def self.shutdown
      @pool.shutdown
      @pool.wait_for_termination(60)
    end
  end
end
