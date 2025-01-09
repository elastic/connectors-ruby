#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'time'
require 'fugit'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'core/filtering/validation_status'
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
          if filtering_validation_triggered?(cs)
            yield cs, :filter_validation
          end
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

    def shutdown
      Utility::Logger.info("Shutting down scheduler #{self.class.name}.")
      @is_shutting_down = true
    end

    private

    def sync_triggered?(connector_settings, time_at_poll_start = Time.now)
      unless connector_settings.valid_index_name?
        Utility::Logger.warn("The index name of #{connector_settings.formatted} is invalid.")
        return false
      end

      unless connector_settings.connector_status_allows_sync?
        Utility::Logger.info("#{connector_settings.formatted.capitalize} is in status \"#{connector_settings.connector_status}\" and won't sync yet. Connector needs to be in one of the following statuses: #{Connectors::ConnectorStatus::STATUSES_ALLOWING_SYNC} to run.")

        return false
      end

      # Sync when sync_now flag is true for the connector
      if connector_settings.sync_now?
        Utility::Logger.info("#{connector_settings.formatted.capitalize} is manually triggered to sync now.")
        return true
      end

      schedule_triggered?(connector_settings.full_sync_scheduling, connector_settings.formatted, time_at_poll_start)
    end

    def heartbeat_triggered?(connector_settings)
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
      connector_settings.needs_service_type? || connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
    end

    def filtering_validation_triggered?(connector_settings)
      unless connector_settings.any_filtering_feature_enabled?
        Utility::Logger.debug("#{connector_settings.formatted} all filtering features are disabled. Skip filtering validation.")

        return false
      end

      filtering = connector_settings.filtering

      unless filtering.present?
        Utility::Logger.debug("#{connector_settings.formatted} does not contain filtering to be validated.")

        return false
      end

      draft_filters = filtering[:draft]

      unless draft_filters.present?
        Utility::Logger.debug("#{connector_settings.formatted} does not contain a draft filter to be validated.")

        return false
      end

      validation = draft_filters[:validation]

      unless validation.present?
        Utility::Logger.warn("#{connector_settings.formatted} does not contain a validation object inside draft filtering. Check connectors index.")

        return false
      end

      unless validation[:state] == Core::Filtering::ValidationStatus::EDITED
        Utility::Logger.debug("#{connector_settings.formatted} filtering validation needs to be in state #{Core::Filtering::ValidationStatus::EDITED} to be able to validate it.")

        return false
      end

      true
    end

    def connector_registered?(service_type)
      if Connectors::REGISTRY.registered?(service_type)
        true
      else
        Utility::Logger.warn("The service type (#{service_type}) is not supported.")
        false
      end
    end

    def schedule_triggered?(scheduling_settings, identifier, time_at_poll_start = Time.now)
      # Don't sync if sync is explicitly disabled
      unless scheduling_settings.present? && scheduling_settings[:enabled] == true
        Utility::Logger.debug("#{identifier.capitalize} scheduling is disabled.")
        return false
      end

      current_schedule = scheduling_settings[:interval]

      # Don't sync if there is no actual scheduling interval
      if current_schedule.nil? || current_schedule.empty?
        Utility::Logger.warn("No sync schedule configured for #{identifier}.")
        return false
      end

      current_schedule =
        begin
          Utility::Cron.quartz_to_crontab(current_schedule)
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, "Unable to convert quartz (#{current_schedule}) to crontab.")
          return false
        end
      cron_parser = Fugit::Cron.parse(current_schedule)

      # Don't sync if the scheduling interval is non-parsable
      unless cron_parser
        Utility::Logger.error("Unable to parse sync schedule for #{identifier}: expression #{current_schedule} is not a valid Quartz Cron definition.")
        return false
      end

      next_trigger_time = cron_parser.next_time(time_at_poll_start)
      # Sync if next trigger happens before the next poll
      poll_window = time_at_poll_start + @poll_interval
      if next_trigger_time <= poll_window
        Utility::Logger.info("#{identifier.capitalize} sync is triggered by cron schedule #{current_schedule}.")
        return true
      else
        # log that a sync was not triggered, share the next trigger time and when poll interval was meant to end
        Utility::Logger.debug("Sync for #{identifier.capitalize} not triggered as #{next_trigger_time} occurs after the poll window #{poll_window}. Poll window began at #{time_at_poll_start}, poll interval is #{@poll_interval} seconds.")
      end

      false
    end

    def sleep_for_poll_interval
      if @poll_interval > 0 && !@is_shutting_down
        Utility::Logger.debug("Sleeping for #{@poll_interval} seconds in #{self.class}.")
        sleep(@poll_interval)
      end
    end

    def log_authorization_error(e)
      Utility::ExceptionTracking.log_exception(e, 'Could not retrieve connectors settings due to authorization error.')
    end

    def log_standard_error(e)
      Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
    end
  end
end
