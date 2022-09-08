#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'core'
require 'utility'
require 'app/config'

module App
  class Worker
    POLL_IDLING = (App::Config[:idle_timeout] || 60).to_i

    def initialize(connector_id:, service_type:)
      super()
      @connector_id = connector_id
      @service_type = service_type
    end

    def start!
      Utility::Logger.info('Running pre-flight check.')
      pre_flight_check
      Utility::Logger.info('Starting connector service workers.')
      start_heartbeat_task
      start_polling_jobs
    end

    private

    def pre_flight_check
      raise "#{@service_type} is not a supported connector" unless Connectors::REGISTRY.registered?(@service_type)
      begin
        connector_settings = Core::ConnectorSettings.fetch(@connector_id)
        Core::ElasticConnectorActions.ensure_content_index_exists(connector_settings.index_name)
      rescue Elastic::Transport::Transport::Errors::Unauthorized => e
        raise "Elasticsearch is not authorizing access #{e}"
      end
    end

    def start_heartbeat_task
      Core::Heartbeat.start_task(@connector_id, @service_type)
    end

    def start_polling_jobs
      Utility::Logger.info("Polling Elasticsearch for synchronisation jobs to run on #{@connector_id} - #{@service_type}...")
      Core::SingleScheduler.new(@connector_id, POLL_IDLING).when_triggered do |connector_settings|
        job_runner = Core::SyncJobRunner.new(connector_settings, @service_type)
        job_runner.execute
      end
    end
  end
end
