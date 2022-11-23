#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/connector_status'
require 'connectors/sync_status'
require 'core/elastic_connector_actions'
require 'utility'

module Core
  class ConnectorSettings

    DEFAULT_REQUEST_PIPELINE = 'ent-search-generic-ingestion'
    DEFAULT_EXTRACT_BINARY_CONTENT = true
    DEFAULT_REDUCE_WHITESPACE = true
    DEFAULT_RUN_ML_INFERENCE = true

    DEFAULT_FILTERING = {}

    DEFAULT_PAGE_SIZE = 100

    def self.fetch_by_id(connector_id)
      es_response = ElasticConnectorActions.get_connector(connector_id)
      return nil unless es_response[:found]

      connectors_meta = ElasticConnectorActions.connectors_meta
      new(es_response, connectors_meta)
    end

    def self.fetch_native_connectors(page_size = DEFAULT_PAGE_SIZE)
      require 'connectors/registry' unless defined?(Connectors::REGISTRY)
      query = {
        bool: {
          filter: [
            { term: { is_native: true } },
            { terms: { service_type: Connectors::REGISTRY.registered_connectors } }
          ]
        }
      }
      fetch_connectors_by_query(query, page_size)
    end

    def self.fetch_crawler_connectors(page_size = DEFAULT_PAGE_SIZE)
      query = { term: { service_type: Utility::Constants::CRAWLER_SERVICE_TYPE } }
      fetch_connectors_by_query(query, page_size)
    end

    def self.fetch_all_connectors(page_size = DEFAULT_PAGE_SIZE)
      query = { match_all: {} }
      fetch_connectors_by_query(query, page_size)
    end

    def id
      @elasticsearch_response[:_id]
    end

    def [](property_name)
      # TODO: handle not found
      @elasticsearch_response[:_source][property_name]
    end

    def index_name
      self[:index_name]
    end

    def connector_status
      self[:status]
    end

    def connector_status_allows_sync?
      Connectors::ConnectorStatus::STATUSES_ALLOWING_SYNC.include?(connector_status)
    end

    def service_type
      self[:service_type]
    end

    def configuration
      self[:configuration]
    end

    def scheduling_settings
      self[:scheduling]
    end

    def filtering
      # assume for now, that first object in filtering array or a filter object itself is the only filtering object
      filtering = @elasticsearch_response.dig(:_source, :filtering)

      Utility::Filtering.extract_filter(filtering)
    end

    def request_pipeline
      Utility::Common.return_if_present(@elasticsearch_response.dig(:_source, :pipeline, :name), @connectors_meta.dig(:pipeline, :default_name), DEFAULT_REQUEST_PIPELINE)
    end

    def extract_binary_content?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:_source, :pipeline, :extract_binary_content), @connectors_meta.dig(:pipeline, :default_extract_binary_content), DEFAULT_EXTRACT_BINARY_CONTENT)
    end

    def reduce_whitespace?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:_source, :pipeline, :reduce_whitespace), @connectors_meta.dig(:pipeline, :default_reduce_whitespace), DEFAULT_REDUCE_WHITESPACE)
    end

    def run_ml_inference?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:_source, :pipeline, :run_ml_inference), @connectors_meta.dig(:pipeline, :default_run_ml_inference), DEFAULT_RUN_ML_INFERENCE)
    end

    def formatted
      properties = ["ID: #{id}"]
      properties << "Service type: #{service_type}" if service_type
      "connector (#{properties.join(', ')})"
    end

    def needs_service_type?
      service_type.to_s.strip.empty?
    end

    def valid_index_name?
      index_name&.start_with?(Utility::Constants::CONTENT_INDEX_PREFIX)
    end

    def ready_for_sync?
      Connectors::REGISTRY.registered?(service_type) &&
        valid_index_name? &&
        connector_status_allows_sync?
    end

    def running?
      @elasticsearch_response[:_source][:last_sync_status] == Connectors::SyncStatus::IN_PROGRESS
    end

    def update_last_sync!(job)
      # if job is nil, connector still needs to be updated, to avoid it stuck at in_progress
      job_status = job&.status || Connectors::SyncStatus::ERROR
      job_error = job.nil? ? 'Could\'t find the job' : job.error
      job_error ||= 'unknown error' if job_status == Connectors::SyncStatus::ERROR
      connector_status = job_status == Connectors::SyncStatus::ERROR ? Connectors::ConnectorStatus::ERROR : Connectors::ConnectorStatus::CONNECTED
      doc = {
        :last_sync_status => job_status,
        :last_synced => Time.now,
        :last_sync_error => job_error,
        :status => connector_status,
        :error => job_error
      }
      if job&.terminated?
        doc[:last_indexed_document_count] = job[:indexed_document_count]
        doc[:last_deleted_document_count] = job[:deleted_document_count]
      end
      Core::ElasticConnectorActions.update_connector_fields(id, doc)
    end

    private

    def initialize(es_response, connectors_meta)
      @elasticsearch_response = es_response.with_indifferent_access
      @connectors_meta = connectors_meta.with_indifferent_access
    end

    def self.fetch_connectors_by_query(query, page_size)
      connectors_meta = ElasticConnectorActions.connectors_meta

      results = []
      offset = 0
      loop do
        response = ElasticConnectorActions.search_connectors(query, page_size, offset)

        hits = response.dig('hits', 'hits') || []
        total = response.dig('hits', 'total', 'value') || 0
        results += hits.map do |hit|
          Core::ConnectorSettings.new(hit, connectors_meta)
        end
        break if results.size >= total
        offset += hits.size
      end

      results
    end

  end
end
