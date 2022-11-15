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
      super("Connector job (ID: '#{job_id}') is in status of '#{status}'.")
    end
  end

  class SyncJobRunner
    JOB_REPORTING_INTERVAL = 10

    def initialize(connector_settings, job, max_ingestion_queue_size, max_ingestion_queue_bytes)
      @connector_settings = connector_settings
      @connector_id = connector_settings.id
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
      @connector_instance = nil
      @sync_status = nil
      @sync_error = nil
      @job = nil
    end

    def execute
      validate_configuration!
      do_sync!
    end

    private

    def do_sync!
      Utility::Logger.info("Claiming a sync job for connector #{@connector_id}.")

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

        @connector_instance = Connectors::REGISTRY.connector(@connector_settings.service_type, @connector_settings.configuration, job_description: @job)

        @connector_instance.do_health_check!

        incoming_ids = []
        existing_ids = ElasticConnectorActions.fetch_document_ids(@connector_settings.index_name)

        Utility::Logger.debug("#{existing_ids.size} documents are present in index #{@connector_settings.index_name}.")

        post_processing_engine = Core::Filtering::PostProcessEngine.new(@job.filtering)
        @reporting_cycle_start = Time.now
        Utility::Logger.info('Yielding documents...')
        @connector_instance.yield_documents do |document|
          document = add_ingest_metadata(document)
          post_process_result = post_processing_engine.process(document)
          if post_process_result.is_include?
            @sink.ingest(document)
            incoming_ids << document['id']
          end

          periodically do
            check_job
            @job.heartbeat!(@sink.ingestion_stats, @connector_instance.metadata)
          end
        end

        ids_to_delete = existing_ids - incoming_ids.uniq

        Utility::Logger.info("Deleting #{ids_to_delete.size} documents from index #{@connector_settings.index_name}.")

        ids_to_delete.each do |id|
          @sink.delete(id)

          periodically do
            check_job
            @job.heartbeat!(@sink.ingestion_stats, @connector_instance.metadata)
          end
        end

        @sink.flush

        # force check at the end
        check_job

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
        Utility::Logger.info("Upserted #{stats[:indexed_document_count]} documents into #{@connector_settings.index_name}.")
        Utility::Logger.info("Deleted #{stats[:deleted_document_count]} documents into #{@connector_settings.index_name}.")

        # Make sure to not override a previous error message
        @sync_status ||= Connectors::SyncStatus::ERROR
        @sync_error = 'Sync thread didn\'t finish execution. Check connector logs for more details.' if @sync_status == Connectors::SyncStatus::ERROR && @sync_error.nil?

        if @job = ConnectorJob.fetch_by_id(@job_id)
          case @sync_status
          when Connectors::SyncStatus::COMPLETED
            @job.done!(stats, @connector_instance&.metadata)
          when Connectors::SyncStatus::CANCELED
            @job.cancel!(stats, @connector_instance&.metadata)
          when Connectors::SyncStatus::ERROR
            @job.error!(@sync_error, stats, @connector_instance&.metadata)
          else
            Utility::Logger.error("The job is supposed to be in one of the terminal statuses (#{Connectors::SyncStatus::TERMINAL_STATUSES.join(', ')}), but it's #{@sync_status}")
            @sync_status = Connectors::SyncStatus::ERROR
            @sync_error = 'The job is not ended as expected for unknown reason'
            @job.error!(@sync_error, stats, @connector_instance&.metadata)
          end
        end

        if @connector_settings = ConnectorSettings.fetch_by_id(@connector_id)
          @connector_settings.update_last_sync!(@job)
        end

        Utility::Logger.info("Completed the job (ID: #{@job_id}) with status: #{@sync_status}#{@sync_error ? " and error: #{@sync_error}" : ''}")
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

      wrong_state_error = Utility::InvalidFilterConfigError.new("Active filtering is not in valid state (current state: #{validation_result[:state]}) for connector #{@connector_id}. Please check active filtering in connectors index.")
      raise wrong_state_error if validation_result[:state] != Core::Filtering::ValidationStatus::VALID

      errors_present_error = Utility::InvalidFilterConfigError.new("Active filtering is in valid state, but errors were detected (errors: #{validation_result[:errors]}) for connector #{@connector_id}. Please check active filtering in connectors index.")
      raise errors_present_error if validation_result[:errors].present?
    end

    def periodically
      return if Time.now - @reporting_cycle_start < JOB_REPORTING_INTERVAL

      yield if block_given?

      @reporting_cycle_start = Time.now
    end

    def check_job
      # raise error if the connector is deleted
      if (@connector_settings = ConnectorSettings.fetch_by_id(@connector_id)).nil?
        raise ConnectorNotFoundError(@connector_id)
      end

      # raise error if the job is deleted
      if (@job = ConnectorJob.fetch_by_id(@job_id)).nil?
        raise ConnectorJobNotFoundError(@job_id)
      end

      # raise error if the job is canceled
      raise ConnectorJobCanceledError.new(@job_id) if @job.canceling?

      # raise error if the job is not in the status in_progress
      raise InvalidConnectorJobStatusError.new(@job_id, @job.status) unless @job.in_progress?
    end
  end
end
