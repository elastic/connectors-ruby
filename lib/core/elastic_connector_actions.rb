#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
#
require 'active_support/core_ext/hash'
require 'utility/elasticsearch/index/mappings'
require 'utility/elasticsearch/index/text_analysis_settings'

module Core
  class ElasticConnectorActions
    CONNECTORS_INDEX = '.elastic-connectors'
    JOB_INDEX = '.elastic-connectors-sync-jobs'

    class << self

      def force_sync(connector_package_id)
        body = {
          :doc => {
            :scheduling => { :enabled => true },
            :sync_now => true
          }
        }
        client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
        Utility::Logger.info("Successfully pushed sync_now flag for connector #{connector_package_id}")
      end

      def create_connector(index_name, service_type)
        body = {
          :scheduling => { :enabled => true },
          :index_name => index_name,
          :service_type => service_type
        }
        response = client.index(:index => CONNECTORS_INDEX, :body => body)
        created_id = response['_id']
        Utility::Logger.info("Successfully registered connector #{index_name} with ID #{created_id}")
        created_id
      end

      def load_connector_settings(connector_package_id)
        client.get(:index => CONNECTORS_INDEX, :id => connector_package_id, :ignore => 404).with_indifferent_access
      end

      def update_connector_configuration(connector_package_id, configuration)
        update_connector_field(connector_package_id, :configuration, configuration)
      end

      def enable_connector_scheduling(connector_package_id, cron_expression)
        payload = { :enabled => true, :interval => cron_expression }
        update_connector_field(connector_package_id, :scheduling, payload)
      end

      def disable_connector_scheduling(connector_package_id)
        payload = { :enabled => false }
        update_connector_field(connector_package_id, :scheduling, payload)
      end

      def set_configurable_field(connector_package_id, field_name, label, value)
        payload = { field_name => { :value => value, :label => label } }
        update_connector_field(connector_package_id, :configuration, payload)
      end

      def claim_job(connector_package_id)
        body = {
          :doc => {
            :sync_now => false,
            :last_sync_status => Connectors::SyncStatus::IN_PROGRESS,
            :last_synced => Time.now
          }
        }

        client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)

        body = {
          :connector_id => connector_package_id,
          :status => Connectors::SyncStatus::IN_PROGRESS,
          :worker_hostname => Socket.gethostname,
          :created_at => Time.now
        }
        job = client.index(:index => JOB_INDEX, :body => body)

        Utility::Logger.info("Successfully claimed job for connector #{connector_package_id}")
        job['_id']
      end

      def complete_sync(connector_package_id, job_id, status)
        sync_status = status[:error] ? Connectors::SyncStatus::FAILED : Connectors::SyncStatus::COMPLETED

        body = {
          :doc => {
            :last_sync_status => sync_status,
            :last_sync_error => status[:error],
            :last_synced => Time.now
          }
        }

        client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)

        body = {
          :doc => {
              :status => sync_status,
              :completed_at => Time.now
          }.merge(status)
        }
        client.update(:index => JOB_INDEX, :id => job_id, :body => body)

        if status[:error]
          Utility::Logger.info("Failed to sync for connector #{connector_package_id} with error #{status[:error]}")
        else
          Utility::Logger.info("Successfully synced for connector #{connector_package_id}")
        end
      end

      def client
        @client ||= Utility::EsClient.new
      end

      # should only be used in CLI
      def ensure_content_index_exists(index_name, use_icu_locale = false, language_code = nil)
        settings = Utility::Elasticsearch::Index::TextAnalysisSettings.new(:language_code => language_code, :analysis_icu => use_icu_locale).to_h
        mappings = Utility::Elasticsearch::Index::Mappings.default_text_fields_mappings(:connectors_index => true)

        body_payload = { settings: settings, mappings: mappings }
        ensure_index_exists(index_name, body_payload)
      end

      # should only be used in CLI
      def ensure_index_exists(index_name, body = {})
        client.indices.create(:index => index_name, :body => body) unless client.indices.exists?(:index => index_name)
      end

      def system_index_body(alias_name: nil, mappings: nil)
        body = {
          :settings => {
            :index => {
              :hidden => true
            }
          }
        }
        body[:aliases] = { alias_name => { :is_write_index => true } } unless alias_name.nil? || alias_name.empty?
        body[:mappings] = mappings unless mappings.nil?
        body
      end

      def ensure_connectors_index_exists
        mappings = {
          :properties => {
            :api_key_id => { :type => :keyword },
            :configuration => { :type => :object },
            :error => { :type => :text },
            :index_name => { :type => :keyword },
            :last_seen => { :type => :date },
            :last_synced => { :type => :date },
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
        ensure_index_exists("#{CONNECTORS_INDEX}-v1", system_index_body(:alias_name => CONNECTORS_INDEX, :mappings => mappings))
      end

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
        ensure_index_exists("#{JOB_INDEX}-v1", system_index_body(:alias_name => JOB_INDEX, :mappings => mappings))
      end

      def update_connector_field(connector_package_id, field_name, value)
        body = {
          :doc => {
            field_name => value
          }
        }
        client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
        Utility::Logger.info("Successfully updated field #{field_name} connector #{connector_package_id}")
      end
    end
  end
end
