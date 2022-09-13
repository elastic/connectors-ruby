#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'
require 'connectors/connector_status'
require 'core/elastic_connector_actions'
require 'time'
require 'utility/logger'

module Core
  class ConnectorSettings

    DEFAULT_REQUEST_PIPELINE = 'ent-search-generic-ingestion'
    DEFAULT_EXTRACT_BINARY_CONTENT = true
    DEFAULT_REDUCE_WHITESPACE = true
    DEFAULT_RUN_ML_INFERENCE = false

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

    def self.fetch_crawler_connectors
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

    def request_pipeline
      return_if_present(@elasticsearch_response.dig(:pipeline, :name), @connectors_meta.dig(:pipeline, :default_name), DEFAULT_REQUEST_PIPELINE)
    end

    def extract_binary_content?
      return_if_present(@elasticsearch_response.dig(:pipeline, :extract_binary_content), @connectors_meta.dig(:pipeline, :default_extract_binary_content), DEFAULT_EXTRACT_BINARY_CONTENT)
    end

    def reduce_whitespace?
      return_if_present(@elasticsearch_response.dig(:pipeline, :reduce_whitespace), @connectors_meta.dig(:pipeline, :default_reduce_whitespace), DEFAULT_REDUCE_WHITESPACE)
    end

    def run_ml_inference?
      return_if_present(@elasticsearch_response.dig(:pipeline, :run_ml_inference), @connectors_meta.dig(:pipeline, :default_run_ml_inference), DEFAULT_RUN_ML_INFERENCE)
    end

    private

    def self.fetch_connectors_by_query(query, page_size)
      connectors_meta = ElasticConnectorActions.connectors_meta

      results = []
      offset = 0
      loop do
        response = ElasticConnectorActions.search_connectors(query, page_size, offset)

        hits = response['hits']['hits']
        total = response['hits']['total']['value']
        results += hits.map do |hit|
          Core::ConnectorSettings.new(hit, connectors_meta)
        end
        break if results.size >= total
        offset += hits.size
      end

      results
    end

    def return_if_present(*args)
      args.each do |arg|
        return arg unless arg.nil?
      end
      nil
    end
  end
end
