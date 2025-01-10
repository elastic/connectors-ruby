#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/scheduler'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'utility/logger'
require 'utility/exception_tracking'

module Connectors
  module Crawler
    class Scheduler < Core::Scheduler
      def connector_settings
        Core::ConnectorSettings.fetch_crawler_connectors || []
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'Could not retrieve Crawler connectors due to unexpected error.')
        []
      end

      def when_triggered
        loop do
          time_at_poll_start = Time.now # grab the time right before we iterate over all connectors
          connector_settings.each do |cs|
            # crawler only supports :sync
            if sync_triggered?(cs, time_at_poll_start)
              yield cs, :sync, nil
              next
            end

            schedule_key = custom_schedule_triggered(cs, time_at_poll_start)
            yield cs, :sync, schedule_key if schedule_key
          end
        rescue *Utility::AUTHORIZATION_ERRORS => e
          log_authorization_error(e)
        rescue StandardError => e
          log_standard_error(e)
        ensure
          if @is_shutting_down
            break
          end
          sleep_for_poll_interval
        end
      end

      private

      def connector_registered?(service_type)
        service_type == 'elastic-crawler'
      end

      # custom scheduling has no ordering, so the first-found schedule is returned
      def custom_schedule_triggered(cs, time_at_poll_start)
        cs.custom_scheduling_settings.each do |key, custom_scheduling|
          identifier = "#{cs.formatted} - #{custom_scheduling[:name]}"
          if schedule_triggered?(custom_scheduling, identifier, time_at_poll_start)
            return key
          end
        end

        nil
      end
    end
  end
end
