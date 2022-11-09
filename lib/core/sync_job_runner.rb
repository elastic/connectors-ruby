#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'
require 'core/ingestion'
require 'utility'

module Core
  class IncompatibleConfigurableFieldsError < StandardError
    def initialize(service_type, expected_fields, actual_fields)
      super("Connector of service_type '#{service_type}' expected configurable fields: #{expected_fields}, actual stored fields: #{actual_fields}")
    end
  end

  class SyncJobRunner
    JOB_REPORTING_INTERVAL = 10

    def initialize(connector_settings)
      @connector_settings = connector_settings
      @ingester = Core::Ingestion::Ingester.new(Core::Ingestion::EsSink.new(connector_settings.index_name, @connector_settings.request_pipeline))
      @connector_class = Connectors::REGISTRY.connector_class(connector_settings.service_type)
      @sync_finished = false
      @sync_error = nil
      @status = {
        :indexed_document_count => 0,
        :deleted_document_count => 0,
        :indexed_document_volume => 0,
        :error => nil
      }
    end

    def execute
      validate_configuration!
      do_sync!
    end

    private

    def do_sync!
      Utility::Logger.info("Claiming a sync job for connector #{@connector_settings.id}.")

      job_record = ElasticConnectorActions.claim_job(@connector_settings.id)
      job_description = job_record['_source']
      job_id = job_record['_id']
      job_description['_id'] = job_id

      unless job_id.present?
        Utility::Logger.error("Failed to claim the job for #{@connector_settings.id}. Please check the logs for the cause of this error.")
        return
      end

      begin
        Utility::Logger.debug("Successfully claimed job for connector #{@connector_settings.id}.")

        connector_instance = Connectors::REGISTRY.connector(@connector_settings.service_type, @connector_settings.configuration, job_description: job_description)

        connector_instance.do_health_check!

        incoming_ids = []
        existing_ids = ElasticConnectorActions.fetch_document_ids(@connector_settings.index_name)

        Utility::Logger.debug("#{existing_ids.size} documents are present in index #{@connector_settings.index_name}.")

        reporting_cycle_start = Time.now
        connector_instance.yield_documents do |document|
          document = add_ingest_metadata(document)
          @ingester.ingest(document)
          incoming_ids << document['id']

          if Time.now - reporting_cycle_start >= JOB_REPORTING_INTERVAL
            ElasticConnectorActions.update_sync(job_id, @sink.ingestion_stats.merge(:metadata => connector_instance.metadata))
            reporting_cycle_start = Time.now
          end
        end

        ids_to_delete = existing_ids - incoming_ids.uniq

        Utility::Logger.info("Deleting #{ids_to_delete.size} documents from index #{@connector_settings.index_name}.")

        ids_to_delete.each do |id|
          @ingester.delete(id)

          if Time.now - reporting_cycle_start >= JOB_REPORTING_INTERVAL
            ElasticConnectorActions.update_sync(job_id, @sink.ingestion_stats.merge(:metadata => connector_instance.metadata))
            reporting_cycle_start = Time.now
          end
        end

        @ingester.flush

        # We use this mechanism for checking, whether an interrupt (or something else lead to the thread not finishing)
        # occurred as most of the time the main execution thread is interrupted and we miss this Signal/Exception here
        @sync_finished = true
      rescue StandardError => e
        @sync_error = e.message
        Utility::ExceptionTracking.log_exception(e)
      ensure
        stats = @ingester.ingestion_stats

        Utility::Logger.debug("Sync stats are: #{stats}")

        @status[:indexed_document_count] = stats[:indexed_document_count]
        @status[:deleted_document_count] = stats[:deleted_document_count]
        @status[:indexed_document_volume] = stats[:indexed_document_volume]

        Utility::Logger.info("Upserted #{@status[:indexed_document_count]} documents into #{@connector_settings.index_name}.")
        Utility::Logger.info("Deleted #{@status[:deleted_document_count]} documents into #{@connector_settings.index_name}.")

        # Make sure to not override a previous error message
        if !@sync_finished && @sync_error.nil?
          @sync_error = 'Sync thread didn\'t finish execution. Check connector logs for more details.'
        end

        metadata = @sink.ingestion_stats.merge(:metadata => connector_instance.metadata)
        metadata[:total_document_count] = ElasticConnectorActions.document_count(@connector_settings.index_name)

        ElasticConnectorActions.complete_sync(@connector_settings.id, job_id, metadata, @sync_error)

        if @sync_error
          Utility::Logger.info("Failed to sync for connector #{@connector_settings.id} with error '#{@sync_error}'.")
        else
          Utility::Logger.info("Successfully synced for connector #{@connector_settings.id}.")
        end
      end
    end

    def add_ingest_metadata(document)
      document.tap do |it|
        it['_extract_binary_content'] = @connector_settings.extract_binary_content? if @connector_settings.extract_binary_content?
        it['_reduce_whitespace'] = @connector_settings.reduce_whitespace? if @connector_settings.reduce_whitespace?
        it['_run_ml_inference'] = @connector_settings.run_ml_inference? if @connector_settings.run_ml_inference?
      end
    end

    def validate_configuration!
      expected_fields = @connector_class.configurable_fields.keys.map(&:to_s).sort
      actual_fields = @connector_settings.configuration.keys.map(&:to_s).sort

      raise IncompatibleConfigurableFieldsError.new(@connector_class.service_type, expected_fields, actual_fields) if expected_fields != actual_fields
    end
  end
end
