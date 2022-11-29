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

  class ConnectorJobNotRunningError < StandardError
    def initialize(job_id, status)
      super("Connector job (ID: '#{job_id}') is not running but in status of '#{status}'.")
    end
  end

  class SyncJobRunner
    JOB_REPORTING_INTERVAL = 10

    def initialize(connector_settings, job, max_ingestion_queue_size, max_ingestion_queue_bytes)
      @connector_settings = connector_settings
      @connector_id = connector_settings.id
      @index_name = job.index_name
      @service_type = job.service_type
      @job = job
      @job_id = job.id
      @sink = Core::Ingestion::EsSink.new(
        @index_name,
        @connector_settings.request_pipeline,
        Utility::BulkQueue.new(
          max_ingestion_queue_size,
          max_ingestion_queue_bytes
        ),
        max_ingestion_queue_bytes
      )
      @connector_class = Connectors::REGISTRY.connector_class(@service_type)
    end

    def execute
      validate_configuration!
      do_sync!
    end

    private

    def do_sync!
      return unless claim_job!

      begin
        Utility::Logger.info("Checking active filtering for sync job #{@job_id} for connector #{@connector_id}.")
        validate_filtering(@job.filtering)
        Utility::Logger.debug("Active filtering for sync job #{@job_id} for connector #{@connector_id} is valid.")

        @connector_instance = Connectors::REGISTRY.connector(@service_type, @connector_settings.configuration, job_description: @job)
        @connector_instance.do_health_check!

        @sync_status = nil
        @sync_error = nil
        @reporting_cycle_start = Time.now

        incoming_ids = []
        existing_ids = ElasticConnectorActions.fetch_document_ids(@index_name)

        Utility::Logger.debug("#{existing_ids.size} documents are present in index #{@index_name}.")

        post_processing_engine = Core::Filtering::PostProcessEngine.new(@job.filtering)
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
            @job.update_metadata(@sink.ingestion_stats, @connector_instance.metadata)
          end
        end

        ids_to_delete = existing_ids - incoming_ids.uniq

        Utility::Logger.info("Deleting #{ids_to_delete.size} documents from index #{@index_name}.")

        ids_to_delete.each do |id|
          @sink.delete(id)

          periodically do
            check_job
            @job.update_metadata(@sink.ingestion_stats, @connector_instance.metadata)
          end
        end

        @sink.flush

        # force check at the end
        check_job

        # We use this mechanism for checking, whether an interrupt (or something else lead to the thread not finishing)
        # occurred as most of the time the main execution thread is interrupted and we miss this Signal/Exception here
        @sync_status = Connectors::SyncStatus::COMPLETED
        @sync_error = nil
      rescue ConnectorNotFoundError, ConnectorJobNotFoundError, ConnectorJobNotRunningError => e
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
        Utility::Logger.info("Upserted #{stats[:indexed_document_count]} documents into #{@index_name}.")
        Utility::Logger.info("Deleted #{stats[:deleted_document_count]} documents into #{@index_name}.")

        # Make sure to not override a previous error message
        @sync_status ||= Connectors::SyncStatus::ERROR
        @sync_error = 'Sync thread didn\'t finish execution. Check connector logs for more details.' if @sync_status == Connectors::SyncStatus::ERROR && @sync_error.nil?

        # update job if it's still present
        if reload_job!
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
          # need to reload the job to get the latest job status
          reload_job!
        end

        # update connector if it's still present
        if reload_connector!
          @connector_settings.update_last_sync!(@job)
        end

        Utility::Logger.info("Completed the job (ID: #{@job_id}) with status: #{@sync_status}#{@sync_error ? " and error: #{@sync_error}" : ''}")
      end
    end

    def claim_job!
      Utility::Logger.info("Claiming job (ID: #{@job_id}) for connector (ID: #{@connector_id}).")

      # connector service doesn't support multiple jobs running simultaneously
      if @connector_settings.running?
        Utility::Logger.warn("Failed to claim job (ID: #{@job_id}) for connector (ID: #{@connector_id}), there are already jobs running.")
        return false
      end

      begin
        Core::ElasticConnectorActions.update_connector_last_sync_status(@connector_id, Connectors::SyncStatus::IN_PROGRESS)

        @job.make_running!

        Utility::Logger.info("Successfully claimed job (ID: #{@job_id}) for connector (ID: #{@connector_id}).")
        true
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e)
        Utility::Logger.error("Failed to claim job (ID: #{@job_id}) for connector (ID: #{@connector_id}). Please check the logs for the cause of this error.")
        false
      end
    end

    def add_ingest_metadata(document)
      return document unless @job
      document.tap do |it|
        it['_extract_binary_content'] = @job.extract_binary_content? if @job.extract_binary_content?
        it['_reduce_whitespace'] = @job.reduce_whitespace? if @job.reduce_whitespace?
        it['_run_ml_inference'] = @job.run_ml_inference? if @job.run_ml_inference?
      end
    end

    def validate_configuration!
      expected_fields = @connector_class.configurable_fields.keys.map(&:to_s).sort
      actual_fields = @job.configuration.keys.map(&:to_s).sort

      raise IncompatibleConfigurableFieldsError.new(@service_type, expected_fields, actual_fields) if expected_fields != actual_fields
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
      raise ConnectorNotFoundError.new(@connector_id) unless reload_connector!

      # raise error if the job is deleted
      raise ConnectorJobNotFoundError.new(@job_id) unless reload_job!

      # raise error if the job is canceled
      raise ConnectorJobCanceledError.new(@job_id) if @job.canceling?

      # raise error if the job is not in the status in_progress
      raise ConnectorJobNotRunningError.new(@job_id, @job.status) unless @job.in_progress?
    end

    def reload_job!
      @job = ConnectorJob.fetch_by_id(@job_id)
    end

    def reload_connector!
      @connector_settings = ConnectorSettings.fetch_by_id(@connector_id)
    end
  end
end
