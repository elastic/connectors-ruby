#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
#
require 'active_support/core_ext/hash'
require 'connectors/connector_status'
require 'connectors/sync_status'
require 'utility'
require 'elastic-transport'

module Core
  class JobAlreadyRunningError < StandardError
    def initialize(connector_id)
      super("Sync job for connector '#{connector_id}' is already running.")
    end
  end

  class ConnectorVersionChangedError < StandardError
    def initialize(connector_id, seq_no, primary_term)
      super("Version conflict: seq_no [#{seq_no}] and primary_term [#{primary_term}] do not match for connector '#{connector_id}'.")
    end
  end

  class ElasticConnectorActions
    class << self

      def force_sync(connector_id)
        update_connector_fields(connector_id, :scheduling => { :enabled => true }, :sync_now => true)
      end

      def create_connector(index_name, service_type)
        body = {
          :scheduling => { :enabled => true },
          :index_name => index_name,
          :service_type => service_type
        }
        response = client.index(:index => Utility::Constants::CONNECTORS_INDEX, :body => body)
        response['_id']
      end

      def get_connector(connector_id)
        client.get(:index => Utility::Constants::CONNECTORS_INDEX, :id => connector_id, :ignore => 404).with_indifferent_access
      end

      def connectors_meta
        alias_mappings = client.indices.get_mapping(:index => Utility::Constants::CONNECTORS_INDEX).with_indifferent_access
        index = get_latest_index_in_alias(Utility::Constants::CONNECTORS_INDEX, alias_mappings.keys)
        alias_mappings.dig(index, 'mappings', '_meta') || {}
      end

      def search_connectors(query, page_size, offset)
        client.search(
          :index => Utility::Constants::CONNECTORS_INDEX,
          :ignore => 404,
          :body => {
            :size => page_size,
            :from => offset,
            :query => query,
            :sort => ['name']
          }
        )
      end

      def update_connector_configuration(connector_id, configuration)
        update_connector_fields(connector_id, :configuration => configuration)
      end

      def enable_connector_scheduling(connector_id, cron_expression)
        payload = { :enabled => true, :interval => cron_expression }
        update_connector_fields(connector_id, :scheduling => payload)
      end

      def disable_connector_scheduling(connector_id)
        payload = { :enabled => false }
        update_connector_fields(connector_id, :scheduling => payload)
      end

      def set_configurable_field(connector_id, field_name, label, value)
        payload = { field_name => { :value => value, :label => label } }
        update_connector_configuration(connector_id, payload)
      end

      def claim_job(connector_id)
        seq_no = nil
        primary_term = nil
        sync_in_progress = false
        connector_record = client.get(
          :index => Utility::Constants::CONNECTORS_INDEX,
          :id => connector_id,
          :ignore => 404,
          :refresh => true
        ).tap do |response|
          seq_no = response['_seq_no']
          primary_term = response['_primary_term']
          sync_in_progress = response.dig('_source', 'last_sync_status') == Connectors::SyncStatus::IN_PROGRESS
        end
        if sync_in_progress
          raise JobAlreadyRunningError.new(connector_id)
        end
        update_connector_fields(
          connector_id,
          { :sync_now => false,
            :last_sync_status => Connectors::SyncStatus::IN_PROGRESS,
            :last_synced => Time.now },
          seq_no,
          primary_term
        )

        body = {
          :connector_id => connector_id,
          :status => Connectors::SyncStatus::IN_PROGRESS,
          :worker_hostname => Socket.gethostname,
          :created_at => Time.now,
          :filtering => convert_connector_filtering_to_job_filtering(connector_record.dig('_source', 'filtering'))
        }

        client.index(:index => Utility::Constants::JOB_INDEX, :body => body)
      end

      def convert_connector_filtering_to_job_filtering(connector_filtering)
        return [] unless connector_filtering
        connector_filtering = [connector_filtering] unless connector_filtering.is_a?(Array)
        connector_filtering.each_with_object([]) do |filtering_domain, job_filtering|
          job_filtering << {
            'domain' => filtering_domain['domain'],
            'rules' => filtering_domain.dig('active', 'rules'),
            'advanced_snippet' => filtering_domain.dig('active', 'advanced_snippet'),
            'warnings' => [] # TODO: in https://github.com/elastic/enterprise-search-team/issues/3174
          }
        end
      end

      def update_connector_status(connector_id, status, error_message = nil)
        if status == Connectors::ConnectorStatus::ERROR && error_message.nil?
          raise ArgumentError, 'error_message is required when status is error'
        end
        body = {
          :status => status,
          :error => status == Connectors::ConnectorStatus::ERROR ? error_message : nil
        }
        update_connector_fields(connector_id, body)
      end

      def complete_sync(connector_id, job_id, status)
        sync_status = status[:error] ? Connectors::SyncStatus::ERROR : Connectors::SyncStatus::COMPLETED

        update_connector_fields(connector_id,
                                :last_sync_status => sync_status,
                                :last_sync_error => status[:error],
                                :error => status[:error],
                                :last_synced => Time.now,
                                :last_indexed_document_count => status[:indexed_document_count],
                                :last_deleted_document_count => status[:deleted_document_count])

        body = {
          :doc => {
            :status => sync_status,
            :completed_at => Time.now
          }.merge(status)
        }
        client.update(:index => Utility::Constants::JOB_INDEX, :id => job_id, :body => body)
      end

      def fetch_document_ids(index_name)
        page_size = 1000
        result = []
        begin
          pit_id = client.open_point_in_time(:index => index_name, :keep_alive => '1m', :expand_wildcards => 'all')['id']
          body = {
            :query => { :match_all => {} },
            :sort => [{ :id => { :order => :asc } }],
            :pit => {
              :id => pit_id,
              :keep_alive => '1m'
            },
            :size => page_size,
            :_source => false
          }
          loop do
            response = client.search(:body => body)
            hits = response.dig('hits', 'hits') || []

            ids = hits.map { |h| h['_id'] }
            result += ids
            break if hits.size < page_size

            body[:search_after] = hits.last['sort']
            body[:pit][:id] = response['pit_id']
          end
        ensure
          client.close_point_in_time(:index => index_name, :body => { :id => pit_id })
        end

        result
      end

      def ensure_content_index_exists(index_name, use_icu_locale = false, language_code = nil)
        settings = Utility::Elasticsearch::Index::TextAnalysisSettings.new(:language_code => language_code, :analysis_icu => use_icu_locale).to_h
        mappings = Utility::Elasticsearch::Index::Mappings.default_text_fields_mappings(:connectors_index => true)

        body_payload = { settings: settings, mappings: mappings }
        ensure_index_exists(index_name, body_payload)
      end

      def ensure_index_exists(index_name, body = {})
        if client.indices.exists?(:index => index_name)
          return unless body[:mappings]
          Utility::Logger.debug("Index #{index_name} already exists. Checking mappings...")
          Utility::Logger.debug("New mappings: #{body[:mappings]}")
          response = client.indices.get_mapping(:index => index_name)
          existing = response[index_name]['mappings']
          if existing.empty?
            Utility::Logger.debug("Index #{index_name} has no mappings. Adding mappings...")
            client.indices.put_mapping(:index => index_name, :body => body[:mappings], :expand_wildcards => 'all')
            Utility::Logger.debug("Index #{index_name} mappings added.")
          else
            Utility::Logger.debug("Index #{index_name} already has mappings: #{existing}. Skipping...")
          end
        else
          client.indices.create(:index => index_name, :body => body)
          Utility::Logger.debug("Created index #{index_name}")
        end
      end

      def system_index_body(alias_name: nil, mappings: nil)
        body = {
          :settings => {
            :index => {
              :hidden => true,
              :number_of_replicas => 0,
              :auto_expand_replicas => '0-5'
            }
          }
        }
        body[:aliases] = { alias_name => { :is_write_index => true } } unless alias_name.nil? || alias_name.empty?
        body[:mappings] = mappings unless mappings.nil?
        body
      end

      # DO NOT USE this method
      # Creation of connector index should be handled by Kibana, this method is only used by ftest.rb
      def ensure_connectors_index_exists
        mappings = {
          :properties => {
            :api_key_id => { :type => :keyword },
            :configuration => { :type => :object },
            :error => { :type => :text },
            :index_name => { :type => :keyword },
            :last_seen => { :type => :date },
            :last_synced => { :type => :date },
            :last_indexed_document_count => { :type => :integer },
            :last_deleted_document_count => { :type => :integer },
            :scheduling => {
              :properties => {
                :enabled => { :type => :boolean },
                :interval => { :type => :text }
              }
            },
            :service_type => { :type => :keyword },
            :status => { :type => :keyword },
            :sync_error => { :type => :text },
            :sync_now => { :type => :boolean },
            :sync_status => { :type => :keyword }
          }
        }
        ensure_index_exists("#{Utility::Constants::CONNECTORS_INDEX}-v1", system_index_body(:alias_name => Utility::Constants::CONNECTORS_INDEX, :mappings => mappings))
      end

      # DO NOT USE this method
      # Creation of job index should be handled by Kibana, this method is only used by ftest.rb
      def ensure_job_index_exists
        mappings = {
          :properties => {
            :connector_id => { :type => :keyword },
            :status => { :type => :keyword },
            :error => { :type => :text },
            :worker_hostname => { :type => :keyword },
            :indexed_document_count => { :type => :integer },
            :deleted_document_count => { :type => :integer },
            :created_at => { :type => :date },
            :completed_at => { :type => :date }
          }
        }
        ensure_index_exists("#{Utility::Constants::JOB_INDEX}-v1", system_index_body(:alias_name => Utility::Constants::JOB_INDEX, :mappings => mappings))
      end

      def update_connector_fields(connector_id, doc = {}, seq_no = nil, primary_term = nil)
        return if doc.empty?
        update_args = {
          :index => Utility::Constants::CONNECTORS_INDEX,
          :id => connector_id,
          :body => { :doc => doc },
          :refresh => true,
          :retry_on_conflict => 3
        }
        # seq_no and primary_term are used for optimistic concurrency control
        # see https://www.elastic.co/guide/en/elasticsearch/reference/current/optimistic-concurrency-control.html
        if seq_no && primary_term
          update_args[:if_seq_no] = seq_no
          update_args[:if_primary_term] = primary_term
          update_args.delete(:retry_on_conflict)
        end
        begin
          client.update(update_args)
        rescue Elastic::Transport::Transport::Errors::Conflict
          # VersionConflictException
          # see https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-index_.html#optimistic-concurrency-control-index
          raise ConnectorVersionChangedError.new(connector_id, seq_no, primary_term)
        end
      end

      private

      def client
        @client ||= Utility::EsClient.new(App::Config[:elasticsearch])
      end

      def get_latest_index_in_alias(alias_name, indicies)
        index_versions = indicies.map { |index| index.gsub("#{alias_name}-v", '').to_i }
        index_version = index_versions.max # gets the largest suffix number
        "#{alias_name}-v#{index_version}"
      end
    end
  end
end
