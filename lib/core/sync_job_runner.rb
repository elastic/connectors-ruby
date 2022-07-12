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
require 'utility'

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
      job_id = nil
      unless @connector_settings.configuration_initialized?
        @connector_settings.initialize_configuration(@connector_class.configurable_fields)
      end

      validate_configuration!
      if @connector_instance.source_status[:status] == 'OK'
        ElasticConnectorActions.update_connector_status(@connector_settings.id, Connectors::ConnectorStatus::CONNECTED)
      else
        Utility::Logger.error("Connector #{@connector_settings['_id']} was unable to reach out to the 3rd-party service. Make sure that it has been configured correctly and 3rd-party system is accessible.")
        ElasticConnectorActions.update_connector_status(@connector_settings.id, Connectors::ConnectorStatus::ERROR)

        return
      end

      do_sync! if should_sync?
    end

    private

    def do_sync!
      Utility::Logger.info("Starting to sync for connector #{@connector_settings['_id']}")

      job_id = ElasticConnectorActions.claim_job(@connector_settings.id)

      incoming_ids = []
      existing_ids = ElasticConnectorActions.fetch_document_ids(@connector_settings.index_name)

      @connector_instance.yield_documents(@connector_settings) do |document|
        @sink.ingest(document)
        incoming_ids << document[:id]
        @status[:indexed_document_count] += 1
      end

      ids_to_delete = existing_ids - incoming_ids.uniq

      Utility::Logger.info("Deleting #{ids_to_delete.size} documents from index #{@connector_settings.index_name}")

      ids_to_delete.each do |id_to_delete|
        @sink.delete(id_to_delete)
      end
    rescue StandardError => e
      @status[:error] = e.message
      Utility::ExceptionTracking.log_exception(e)
      ElasticConnectorActions.update_connector_status(@connector_settings.id, Connectors::ConnectorStatus::ERROR)
    ensure
      if job_id.present?
        ElasticConnectorActions.complete_sync(@connector_settings.id, job_id, @status.dup)
      else
        Utility::Logger.info("No scheduled jobs for connector #{@connector_settings.id}. Status: #{@status}")
      end
    end

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
