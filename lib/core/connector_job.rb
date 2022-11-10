#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/sync_status'
require 'core/elastic_connector_actions'
require 'utility'

module Core
  class ConnectorJob
    DEFAULT_PAGE_SIZE = 100

    # Error Classes
    class ConnectorJobNotFoundError < StandardError; end

    def self.fetch_by_id(job_id)
      es_response = ElasticConnectorActions.get_job(job_id)

      raise ConnectorJobNotFoundError.new("Connector job with id=#{job_id} was not found.") unless es_response[:found]
      new(es_response)
    end

    def self.pending_jobs(page_size = DEFAULT_PAGE_SIZE)
      query = { terms: { status: Connectors::SyncStatus::PENDING_STATUES } }
      fetch_jobs_by_query(query, page_size)
    end

    def self.orphaned_jobs(_page_size = DEFAULT_PAGE_SIZE)
      []
    end

    def self.stuck_jobs(_page_size = DEFAULT_PAGE_SIZE)
      []
    end

    def self.enqueue(_connector_id)
      nil
    end

    def id
      @elasticsearch_response[:_id]
    end

    def [](property_name)
      @elasticsearch_response[:_source][property_name]
    end

    def status
      self[:status]
    end

    def in_progress?
      status == Connectors::SyncStatus::IN_PROGRESS
    end

    def canceling?
      status == Connectors::SyncStatus::CANCELING
    end

    def connector_snapshot
      self[:connector]
    end

    def connector_id
      connector_snapshot[:id]
    end

    def index_name
      connector_snapshot[:configuration]
    end

    def language
      connector_snapshot[:language]
    end

    def service_type
      connector_snapshot[:service_type]
    end

    def configuration
      connector_snapshot[:configuration]
    end

    def filtering
      connector_snapshot[:filtering]
    end

    def pipeline
      connector_snapshot[:pipeline]
    end

    def connector
      @connector ||= ConnectorSettings.fetch_by_id(connector_id)
    end

    def connector!
      @connector = nil
      connector
    end

    def reload
      es_response = ElasticConnectorActions.get_job(id)
      raise ConnectorJobNotFoundError.new("Connector job with id=#{id} was not found.") unless es_response[:found]
      @elasticsearch_response = es_response.with_indifferent_access
      @connector = nil
    end

    private

    def initialize(es_response)
      @elasticsearch_response = es_response.with_indifferent_access
    end

    def self.fetch_jobs_by_query(query, page_size)
      results = []
      offset = 0
      loop do
        response = ElasticConnectorActions.search_jobs(query, page_size, offset)

        hits = response.dig('hits', 'hits') || []
        total = response.dig('hits', 'total', 'value') || 0
        results += hits.map { |hit| new(hit) }
        break if results.size >= total
        offset += hits.size
      end

      results
    end
  end
end
