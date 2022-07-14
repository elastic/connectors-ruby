#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/config'
require 'concurrent'
require 'cron_parser'
require 'connectors/registry'
require 'core/output_sink'

module Core
  class IncompatibleConfigurableFieldsError < StandardError
    def initialize(expected_fields, actual_fields)
      super("Connector expected configurable fields: #{expected_fields}, actual stored fields: #{actual_fields}")
    end
  end

  class SyncJobRunner
    def initialize(connector_settings, service_type)
      @connector_settings = connector_settings
      @sink = Core::OutputSink::EsSink.new(connector_settings.index_name)
      @connector_class = Connectors::REGISTRY.connector_class(service_type)
      @connector_instance = Connectors::REGISTRY.connector(service_type)
      @status = {
        :indexed_document_count => 0,
        :deleted_document_count => 0,
        :error => nil
      }
    end

    def execute
      unless @connector_settings.configuration_initialized?
        @connector_settings.update_configuration(@connector_class.configurable_fields)
      end

      validate_configuration!
      return unless should_sync?

      Utility::Logger.info("Starting to sync for connector #{@connector_settings['_id']}")

      job_id = ElasticConnectorActions.claim_job(@connector_settings.id)

      @connector_instance.yield_documents(@connector_settings) do |document|
        @sink.ingest(document)
        @status[:indexed_document_count] += 1
      end
    rescue StandardError => e
      @status[:error] = e.message
    ensure
      if job_id.present?
        ElasticConnectorActions.complete_sync(@connector_settings.id, job_id, @status.dup)
      else
        Utility::Logger.info("No scheduled jobs for connector #{@connector_settings.id}. Status: #{@status}")
      end
    end

    private

    def validate_configuration!
      expected_fields = @connector_class.configurable_fields.keys.map(&:to_s).sort
      actual_fields = @connector_settings.configuration.keys.map(&:to_s).sort

      raise IncompatibleConfigurableFieldsError.new(expected_fields, actual_fields) if expected_fields != actual_fields
    end

    def cron_parser(cronline)
      CronParser.new(cronline)
    rescue ArgumentError => e
      Utility::Logger.error("Fail to parse cronline #{cronline}. Error: #{e.message}")
      nil
    end

    def should_sync?
      # sync_now should have priority over cron
      if @connector_settings[:sync_now] == true
        Utility::Logger.info("Connector #{@connector_settings['_id']} is manually triggered to sync now")
        return true
      end
      scheduling_settings = @connector_settings.scheduling_settings
      unless scheduling_settings.present? && scheduling_settings[:enabled] == true
        Utility::Logger.info("Connector #{@connector_settings['_id']} scheduling is disabled")
        return false
      end

      last_synced = @connector_settings[:last_synced]
      return true if last_synced.nil? || last_synced.empty? # first run

      last_synced = Time.parse(last_synced) # TODO: unhandled exception
      sync_interval = scheduling_settings['interval']
      if sync_interval.nil? || sync_interval.empty? # no interval configured
        Utility::Logger.debug("No sync interval configured for connector #{@connector_settings['_id']}")
        return false
      end
      cron_parser = cron_parser(sync_interval)
      if cron_parser && cron_parser.next(last_synced) < Time.now
        Utility::Logger.info("Connector #{@connector_settings['_id']} sync is triggered by cron schedule #{sync_interval}")
        return true
      end
      false
    end
  end
end
