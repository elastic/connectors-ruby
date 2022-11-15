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

    def self.fetch_by_id(job_id)
      es_response = ElasticConnectorActions.get_job(job_id)
      return nil unless es_response[:found]

      new(es_response)
    end

    def self.pending_jobs(page_size = DEFAULT_PAGE_SIZE)
      query = { terms: { status: Connectors::SyncStatus::PENDING_STATUSES } }
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

    def error
      self[:error]
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

    def suspended?
      status == Connectors::SyncStatus::SUSPENDED
    end

    def canceled?
      status == Connectors::SyncStatus::CANCELED
    end

    def pending?
      Connectors::SyncStatus::PENDING_STATUSES.include?(status)
    end

    def active?
      Connectors::SyncStatus::ACTIVE_STATUSES.include?(status)
    end

    def terminated?
      Connectors::SyncStatus::TERMINAL_STATUSES.include?(status)
    end

    def connector_snapshot
      self[:connector] || {}
    end

    def connector_id
      connector_snapshot[:id]
    end

    def index_name
      connector_snapshot[:index_name]
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
      Utility::Filtering.extract_filter(connector_snapshot[:filtering])
    end

    def pipeline
      connector_snapshot[:pipeline]
    end

    def connector
      @connector ||= ConnectorSettings.fetch_by_id(connector_id)
    end

    def done!(ingestion_stats = {}, connector_metadata = {})
      terminate!(Connectors::SyncStatus::COMPLETED, nil, ingestion_stats, connector_metadata)
    end

    def error!(message, ingestion_stats = {}, connector_metadata = {})
      terminate!(Connectors::SyncStatus::ERROR, message, ingestion_stats, connector_metadata)
    end

    def cancel!(ingestion_stats = {}, connector_metadata = {})
      terminate!(Connectors::SyncStatus::CANCELED, nil, ingestion_stats, connector_metadata)
    end

    private

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

    def initialize(es_response)
      # TODO: remove the usage of with_indifferent_access. The initialize method should expect a hash argument
      @elasticsearch_response = es_response.with_indifferent_access
    end

    def terminate!(status, error = nil, ingestion_stats = {}, connector_metadata = {})
      ingestion_stats ||= {}
      ingestion_stats[:total_document_count] = ElasticConnectorActions.document_count(index_name)
      doc = {
        :last_seen => Time.now,
        :completed_at => Time.now,
        :status => status,
        :error => error
      }.merge(ingestion_stats)
      doc[:canceled_at] = Time.now if status == Connectors::SyncStatus::CANCELED
      doc[:metadata] = connector_metadata if connector_metadata&.any?
      ElasticConnectorActions.update_job_fields(id, doc)
    end
  end
end
