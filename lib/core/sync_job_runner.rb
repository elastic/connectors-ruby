#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'
require 'connectors/sync_status'
require 'core/filtering/post_process_engine'
require 'core/ingestion'
require 'core/filtering/validation_status'
require 'utility'

module Core
  class IncompatibleConfigurableFieldsError < StandardError
    def initialize(service_type, expected_fields, actual_fields)
      super("Connector of service_type '#{service_type}' expected configurable fields: #{expected_fields}, actual stored fields: #{actual_fields}")
    end
  end

  class ConnectorNotFoundError < StandardError
    def initialize(connector_id)
      super("Connector is not found for connector ID '#{connector_id}'.")
    end
  end

  class ConnectorJobNotFoundError < StandardError
    def initialize(job_id)
      super("Connector job is not found for job ID '#{job_id}'.")
    end
  end

  class ConnectorJobCanceledError < StandardError
    def initialize(job_id)
      super("Connector job (ID: '#{job_id}') is requested to be canceled.")
    end
  end

  class InvalidConnectorJobStatusError < StandardError
    def initialize(job_id, status)
      super("Connector job (ID: '#{job_id}') is in status of '#{status}', but supposed to be '#{Connectors::SyncStatus::IN_PROGRESS}'.")
    end
  end

  class SyncJobRunner
    JOB_REPORTING_INTERVAL = 10

    def initialize(connector_settings, job, max_ingestion_queue_size, max_ingestion_queue_bytes)
      @connector_settings = connector_settings
      @sink = Core::Ingestion::EsSink.new(
        connector_settings.index_name,
        @connector_settings.request_pipeline,
        Utility::BulkQueue.new(
          max_ingestion_queue_size,
          max_ingestion_queue_bytes
        ),
        max_ingestion_queue_bytes
      )
      @connector_class = Connectors::REGISTRY.connector_class(connector_settings.service_type)
      @sync_status = nil
      @sync_error = nil
    end

    def execute
      validate_configuration!
      do_sync!
    end

    private

    def do_sync!
      Utility::Logger.info("Claiming a sync job for connector #{@connector_settings.id}.")

      # connector service doesn't support multiple jobs running simultaneously
      raise Core::JobAlreadyRunningError.new(@connector_settings.id) if @connector_settings.running?

      Core::ElasticConnectorActions.update_connector_last_sync_status(@connector_settings.id, Connectors::SyncStatus::IN_PROGRESS)

      # claim the job
      @job.make_running!

      job_description = @job.es_source
      job_id = @job.id
      job_description['_id'] = job_id

      unless job_id.present?
        Utility::Logger.error("Failed to claim the job for #{@connector_settings.id}. Please check the logs for the cause of this error.")
        return
      end

      begin
        Utility::Logger.debug("Successfully claimed job for connector #{@connector_settings.id}.")

        Utility::Logger.info("Checking active filtering for sync job #{job_id} for connector #{@connector_settings.id}.")
        validate_filtering(job_description.dig(:connector, :filtering))
        Utility::Logger.debug("Active filtering for sync job #{job_id} for connector #{@connector_settings.id} is valid.")

        connector_instance = Connectors::REGISTRY.connector(@connector_settings.service_type, @connector_settings.configuration, job_description: job_description)

        connector_instance.do_health_check!

        incoming_ids = []
        existing_ids = ElasticConnectorActions.fetch_document_ids(@connector_settings.index_name)

        Utility::Logger.debug("#{existing_ids.size} documents are present in index #{@connector_settings.index_name}.")

        post_processing_engine = Core::Filtering::PostProcessEngine.new(job_description)
        @reporting_cycle_start = Time.now
        Utility::Logger.info('Yielding documents...')
        connector_instance.yield_documents do |document|
          document = add_ingest_metadata(document)
          post_process_result = post_processing_engine.process(document)
          if post_process_result.is_include?
            @sink.ingest(document)
            incoming_ids << document['id']
          end

          validate_job(job_id, connector_instance)
        end

        ids_to_delete = existing_ids - incoming_ids.uniq

        Utility::Logger.info("Deleting #{ids_to_delete.size} documents from index #{@connector_settings.index_name}.")

        ids_to_delete.each do |id|
          @sink.delete(id)

          validate_job(job_id, connector_instance)
        end

        @sink.flush

        # We use this mechanism for checking, whether an interrupt (or something else lead to the thread not finishing)
        # occurred as most of the time the main execution thread is interrupted and we miss this Signal/Exception here
        @sync_status = Connectors::SyncStatus::COMPLETED
      rescue ConnectorNotFoundError, ConnectorJobNotFoundError, InvalidConnectorJobStatusError => e
        Utility::Logger.error(e.message)
        @sync_status = Connectors::SyncStatus::ERROR
        @sync_error = e.message
      rescue ConnectorJobCanceledError => e
        Utility::Logger.error(e.message)
        @sync_status = Connectors::SyncStatus::CANCELED
        # Cancelation is an expected action and we shouldn't log an error
        @sync_error = nil
      rescue StandardError => e
        @sync_status = Connectors::SyncStatus::ERROR
        @sync_error = e.message
        Utility::ExceptionTracking.log_exception(e)
      ensure
        stats = @sink.ingestion_stats

        Utility::Logger.debug("Sync stats are: #{stats}")

        @status[:indexed_document_count] = stats[:indexed_document_count]
        @status[:deleted_document_count] = stats[:deleted_document_count]
        @status[:indexed_document_volume] = stats[:indexed_document_volume]

        Utility::Logger.info("Upserted #{@status[:indexed_document_count]} documents into #{@connector_settings.index_name}.")
        Utility::Logger.info("Deleted #{@status[:deleted_document_count]} documents into #{@connector_settings.index_name}.")

        # Make sure to not override a previous error message
        @sync_status ||= Connectors::SyncStatus::ERROR
        @sync_error = 'Sync thread didn\'t finish execution. Check connector logs for more details.' if @sync_status == Connectors::SyncStatus::ERROR && @sync_error.nil?

        unless connector_instance.nil?
          metadata = @sink.ingestion_stats.merge(:metadata => connector_instance.metadata)
          metadata[:total_document_count] = ElasticConnectorActions.document_count(@connector_settings.index_name)
        end

        ElasticConnectorActions.complete_sync(@connector_settings.id, job_id, @sync_status, @sync_error, metadata)

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

    def validate_filtering(filtering)
      validation_result = @connector_class.validate_filtering(filtering)

      wrong_state_error = Utility::InvalidFilterConfigError.new("Active filtering is not in valid state (current state: #{validation_result[:state]}) for connector #{@connector_settings.id}. Please check active filtering in connectors index.")
      raise wrong_state_error if validation_result[:state] != Core::Filtering::ValidationStatus::VALID

      errors_present_error = Utility::InvalidFilterConfigError.new("Active filtering is in valid state, but errors were detected (errors: #{validation_result[:errors]}) for connector #{@connector_settings.id}. Please check active filtering in connectors index.")
      raise errors_present_error if validation_result[:errors].present?
    end

    def validate_job(job_id, connector_instance)
      return if Time.now - @reporting_cycle_start < JOB_REPORTING_INTERVAL

      # raise error if the connector is deleted
      if ElasticConnectorActions.get_connector(@connector_settings.id).nil?
        raise ConnectorNotFoundError.new(@connector_settings.id)
      end

      # raise error if the job is deleted
      job = ElasticConnectorActions.get_job(job_id)
      raise ConnectorJobNotFoundError.new(job_id) if job.nil?

      # raise error if the job is canceled
      raise ConnectorJobCanceledError.new(job_id) if job[:_source][:status] == Connectors::SyncStatus::CANCELING

      # raise error if the job is not in the status in_progress
      raise InvalidConnectorJobStatusError.new(job_id, job[:_source][:status]) if job[:_source][:status] != Connectors::SyncStatus::IN_PROGRESS

      ElasticConnectorActions.update_sync(job_id, @sink.ingestion_stats.merge(:metadata => connector_instance.metadata))
      @reporting_cycle_start = Time.now
    end
  end
end
