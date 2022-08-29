#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'time'
require 'fugit'
require 'core/connector_settings'
require 'utility/cron'
require 'utility/logger'
require 'utility/exception_tracking'

module Core
  class Scheduler
    attr_reader :is_shutting_down

    def initialize(poll_interval)
      @poll_interval = poll_interval
      @is_shutting_down = is_shutting_down
    end

    def connector_settings
      raise 'Not implemented'
    end

    def when_triggered
      loop do
        connector_settings.each do |cs|
          if sync_triggered?(cs)
            yield cs
          end
        end
        if @is_shutting_down
          break
        end
      end
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
    ensure
      if @poll_interval > 0 && !@is_shutting_down
        Utility::Logger.info("Sleeping for #{@poll_interval} seconds.")
        sleep(@poll_interval)
      end
    end

    def shutdown
      Utility::Logger.info("Shutting down scheduler #{self.class.name}.")
      @is_shutting_down = true
    end

    private

    def sync_triggered?(connector_settings)
      unless connector_settings.connector_status_allows_sync?
        Utility::Logger.info("Connector #{connector_settings.id} is in status \"#{connector_settings.connector_status}\" and won't sync yet. Connector needs to be in one of the following statuses: #{Connectors::ConnectorStatus::STATUSES_ALLOWING_SYNC} to run.")

        return false
      end

      # We want to sync when sync never actually happened
      last_synced = connector_settings[:last_synced]
      if last_synced.nil? || last_synced.empty?
        Utility::Logger.info("Connector #{connector_settings.id} has never synced yet, running initial sync.")
        return true
      end

      # Sync when sync_now flag is true for the connector
      if connector_settings[:sync_now] == true
        Utility::Logger.info("Connector #{connector_settings.id} is manually triggered to sync now.")
        return true
      end

      # Don't sync if sync is explicitly disabled
      scheduling_settings = connector_settings.scheduling_settings
      unless scheduling_settings.present? && scheduling_settings[:enabled] == true
        Utility::Logger.info("Connector #{connector_settings.id} scheduling is disabled.")
        return false
      end

      current_schedule = scheduling_settings[:interval]

      # Don't sync if there is no actual scheduling interval
      if current_schedule.nil? || current_schedule.empty?
        Utility::Logger.warn("No sync schedule configured for connector #{connector_settings.id}.")
        return false
      end

      current_schedule = Utility::Cron.quartz_to_crontab(current_schedule)
      cron_parser = Fugit::Cron.parse(current_schedule)

      # Don't sync if the scheduling interval is non-parsable
      unless cron_parser
        Utility::Logger.error("Unable to parse sync schedule for connector #{connector_settings.id}: expression #{current_schedule} is not a valid Quartz Cron definition.")
        return false
      end

      next_trigger_time = cron_parser.next_time(Time.parse(last_synced))

      # Sync if next trigger for the connector is in past
      if next_trigger_time < Time.now
        Utility::Logger.info("Connector #{connector_settings.id} sync is triggered by cron schedule #{current_schedule}.")
        return true
      end

      false
    end
  end
end
