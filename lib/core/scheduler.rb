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
        if @is_shutting_down
          break
        end
      rescue *Utility::AUTHORIZATION_ERRORS => e
        Utility::ExceptionTracking.log_exception(e, 'Could not retrieve connectors settings due to authorization error.')
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
      ensure
        if @poll_interval > 0 && !@is_shutting_down
          Utility::Logger.debug("Sleeping for #{@poll_interval} seconds in #{self.class}.")
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
      return false unless connector_registered?(connector_settings.service_type)

      unless connector_settings.valid_index_name?
        Utility::Logger.warn("The index name of #{connector_settings.formatted} is invalid.")
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
        Utility::Logger.debug("#{connector_settings.formatted.capitalize} scheduling is disabled.")
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
      return false unless connector_registered?(connector_settings.service_type)

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
      if connector_settings.needs_service_type? || connector_registered?(connector_settings.service_type)
        return connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
      end

      false
    end

    def filtering_validation_triggered?(connector_settings)
      return false unless connector_registered?(connector_settings.service_type)

      filtering = connector_settings.filtering

      unless filtering.present?
        Utility::Logger.info("#{connector_settings.formatted} does not contain filtering to be validated.")

        return false
      end

      draft_filters = filtering[:draft]

      unless draft_filters.present?
        Utility::Logger.info("#{connector_settings.formatted} does not contain a draft filter to be validated.")

        return false
      end

      advanced_filter_config = draft_filters[:advanced_config]

      # rules checking will be added with future work
      unless advanced_filter_config.present?
        Utility::Logger.info("#{connector_settings.formatted} does not contain a draft advanced filter config to be validated.")

        return false
      end

      validation = draft_filters[:validation]

      unless validation.present?
        Utility::Logger.warn("#{connector_settings.formatted} does not contain a validation object inside draft filtering. Check connectors index.")

        return false
      end

      unless validation[:state] == Core::Filtering::ValidationStatus::EDITED
        Utility::Logger.info("#{connector_settings.formatted} filtering validation needs to be in state #{Core::Filtering::ValidationStatus::EDITED} to be able to validate it.")

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
  end
end
