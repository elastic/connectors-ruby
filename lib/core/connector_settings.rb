#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/connector_status'
require 'core/elastic_connector_actions'
require 'utility'

module Core
  class ConnectorSettings

    DEFAULT_REQUEST_PIPELINE = 'ent-search-generic-ingestion'
    DEFAULT_EXTRACT_BINARY_CONTENT = true
    DEFAULT_REDUCE_WHITESPACE = true
    DEFAULT_RUN_ML_INFERENCE = true
    DEFAULT_JOB_REPORTING_INTERVAL = 10

    DEFAULT_FILTERING = {}

    DEFAULT_PAGE_SIZE = 100

    # Error Classes
    class ConnectorNotFoundError < StandardError; end

    def self.fetch_by_id(connector_id)
      es_response = ElasticConnectorActions.get_connector(connector_id)
      connectors_meta = ElasticConnectorActions.connectors_meta

      raise ConnectorNotFoundError.new("Connector with id=#{connector_id} was not found.") unless es_response[:found]
      new(es_response, connectors_meta)
    end

    def initialize(es_response, connectors_meta)
      @elasticsearch_response = es_response.with_indifferent_access
      @connectors_meta = connectors_meta.with_indifferent_access
    end

    def self.fetch_native_connectors(page_size = DEFAULT_PAGE_SIZE)
      query = { term: { is_native: true } }
      fetch_connectors_by_query(query, page_size)
    end

    def self.fetch_crawler_connectors(page_size = DEFAULT_PAGE_SIZE)
      query = { term: { service_type: Utility::Constants::CRAWLER_SERVICE_TYPE } }
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
      Utility::Common.return_if_present(@elasticsearch_response[:filtering], DEFAULT_FILTERING)
    end

    def request_pipeline
      Utility::Common.return_if_present(@elasticsearch_response.dig(:pipeline, :name), @connectors_meta.dig(:pipeline, :default_name), DEFAULT_REQUEST_PIPELINE)
    end

    def extract_binary_content?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:pipeline, :extract_binary_content), @connectors_meta.dig(:pipeline, :default_extract_binary_content), DEFAULT_EXTRACT_BINARY_CONTENT)
    end

    def reduce_whitespace?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:pipeline, :reduce_whitespace), @connectors_meta.dig(:pipeline, :default_reduce_whitespace), DEFAULT_REDUCE_WHITESPACE)
    end

    def run_ml_inference?
      Utility::Common.return_if_present(@elasticsearch_response.dig(:pipeline, :run_ml_inference), @connectors_meta.dig(:pipeline, :default_run_ml_inference), DEFAULT_RUN_ML_INFERENCE)
    end

    def job_reporting_interval
      return_if_present(@connectors_meta.dig(:job, :reporting_interval), DEFAULT_JOB_REPORTING_INTERVAL)
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
