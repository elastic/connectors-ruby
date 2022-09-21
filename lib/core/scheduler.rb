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
    def initialize(poll_interval, heartbeat_interval)
      @poll_interval = poll_interval
      @heartbeat_interval = heartbeat_interval
      @is_shutting_down = false
    end

    def connector_settings
      raise 'Not implemented'
    end

    def when_triggered
      loop do
        connector_settings.each do |cs|
          if sync_triggered?(cs)
            yield cs, :sync
          end
          if heartbeat_triggered?(cs)
            yield cs, :heartbeat
          end
          if configuration_triggered?(cs)
            yield cs, :configuration
          end
        end
        if @is_shutting_down
          break
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
      ensure
        if @poll_interval > 0 && !@is_shutting_down
          Utility::Logger.info("Sleeping for #{@poll_interval} seconds in #{self.class}.")
          sleep(@poll_interval)
        end
      end
    end

    def shutdown
      Utility::Logger.info("Shutting down scheduler #{self.class.name}.")
      @is_shutting_down = true
    end

    private

    def sync_triggered?(connector_settings)
      unless Connectors::REGISTRY.registered?(connector_settings.service_type)
        Utility::Logger.info("The service type (#{connector_settings.service_type}) is not supported.")
        return false
      end

      unless connector_settings.valid_index_name?
        Utility::Logger.info("The index name of #{connector_settings.formatted} is invalid.")
        return false
      end

      unless connector_settings.connector_status_allows_sync?
        Utility::Logger.info("#{connector_settings.formatted.capitalize} is in status \"#{connector_settings.connector_status}\" and won't sync yet. Connector needs to be in one of the following statuses: #{Connectors::ConnectorStatus::STATUSES_ALLOWING_SYNC} to run.")

        return false
      end

      # Sync when sync_now flag is true for the connector
      if connector_settings[:sync_now] == true
        Utility::Logger.info("#{connector_settings.formatted.capitalize} is manually triggered to sync now.")
        return true
      end

      # Don't sync if sync is explicitly disabled
      scheduling_settings = connector_settings.scheduling_settings
      unless scheduling_settings.present? && scheduling_settings[:enabled] == true
        Utility::Logger.info("#{connector_settings.formatted.capitalize} scheduling is disabled.")
        return false
      end

      # We want to sync when sync never actually happened
      last_synced = connector_settings[:last_synced]
      if last_synced.nil? || last_synced.empty?
        Utility::Logger.info("#{connector_settings.formatted.capitalize} has never synced yet, running initial sync.")
        return true
      end

      current_schedule = scheduling_settings[:interval]

      # Don't sync if there is no actual scheduling interval
      if current_schedule.nil? || current_schedule.empty?
        Utility::Logger.warn("No sync schedule configured for #{connector_settings.formatted}.")
        return false
      end

      current_schedule = begin
        Utility::Cron.quartz_to_crontab(current_schedule)
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Unable to convert quartz (#{current_schedule}) to crontab.")
        return false
      end
      cron_parser = Fugit::Cron.parse(current_schedule)

      # Don't sync if the scheduling interval is non-parsable
      unless cron_parser
        Utility::Logger.error("Unable to parse sync schedule for #{connector_settings.formatted}: expression #{current_schedule} is not a valid Quartz Cron definition.")
        return false
      end

      next_trigger_time = cron_parser.next_time(Time.parse(last_synced))

      # Sync if next trigger for the connector is in past
      if next_trigger_time < Time.now
        Utility::Logger.info("#{connector_settings.formatted.capitalize} sync is triggered by cron schedule #{current_schedule}.")
        return true
      end

      false
    end

    def heartbeat_triggered?(connector_settings)
      unless Connectors::REGISTRY.registered?(connector_settings.service_type)
        Utility::Logger.info("The service type (#{connector_settings.service_type}) is not supported.")
        return false
      end

      last_seen = connector_settings[:last_seen]
      return true if last_seen.nil? || last_seen.empty?
      last_seen = begin
        Time.parse(last_seen)
      rescue StandardError
        Utility::Logger.warn("Unable to parse last_seen #{last_seen}")
        nil
      end
      return true unless last_seen
      last_seen + @heartbeat_interval < Time.now
    end

    def configuration_triggered?(connector_settings)
      unless Connectors::REGISTRY.registered?(connector_settings.service_type)
        Utility::Logger.info("The service type (#{connector_settings.service_type}) is not supported.")
        return false
      end

      connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
    end
  end
end
