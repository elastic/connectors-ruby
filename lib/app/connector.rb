#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'framework'
require 'utility'
require 'app/config'

module App
  module Connector
    POLL_IDLING = (App::Config['idle_timeout'] || 60).to_i

    class << self
      def start!
        pre_flight_check

        Utility::Logger.info('Starting to process jobs...')
        start_polling_jobs
      end

      private

      def pre_flight_check
        raise "#{App::Config['service_type']} is not a supported connector" unless Connectors::REGISTRY.registered?(App::Config['service_type'])
      end

      def start_polling_jobs
        loop do
          job_runner = create_sync_job_runner
          job_runner.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
        ensure
          if POLL_IDLING > 0
            Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds")
            sleep(POLL_IDLING)
          end
        end
      end

      def create_sync_job_runner
        connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])

        Framework::SyncJobRunner.new(connector_settings, App::Config['service_type'])
      end
    end
  end
end
