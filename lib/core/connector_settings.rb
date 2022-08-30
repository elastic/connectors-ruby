#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'
require 'connectors/connector_status'
require 'time'
require 'utility/logger'

module Core
  class ConnectorSettings

    DEFAULT_REQUEST_PIPELINE = 'ent-search-generic-ingestion'
    DEFAULT_EXTRACT_BINARY_CONTENT = true
    DEFAULT_REDUCE_WHITESPACE = true
    DEFAULT_RUN_ML_INFERENCE = false

    # Error Classes
    class ConnectorNotFoundError < StandardError; end

    def self.fetch(connector_id)
      es_response = ElasticConnectorActions.get_connector(connector_id)
        .with_indifferent_access

      raise ConnectorNotFoundError.new("Connector with id=#{connector_id} was not found.") unless es_response[:found]
      new(es_response)
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
      self[:request_pipeline] || DEFAULT_REQUEST_PIPELINE
    end

    def extract_binary_content?
      self[:extract_binary_content] || DEFAULT_EXTRACT_BINARY_CONTENT
    end

    def reduce_whitespace?
      self[:reduce_whitespace] || DEFAULT_REDUCE_WHITESPACE
    end

    def run_ml_inference?
      self[:run_ml_inference] || DEFAULT_RUN_ML_INFERENCE
    end

    private

    def initialize(es_response)
      @elasticsearch_response = es_response.with_indifferent_access
    end
  end
end
