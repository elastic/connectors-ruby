#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
#
require 'active_support/core_ext/hash'
require 'utility'

module Framework
  class ElasticConnectorActions
    CONNECTORS_INDEX = '.elastic-connectors'

    def self.force_sync(connector_package_id)
      body = {
        :doc => {
          :scheduling => { :enabled => true },
          :sync_now => true
        }
      }

      client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
      Utility::Logger.info("Successfully pushed sync_now flag for connector #{connector_package_id}")
    end

    def self.create_connector(ingestion_index_name)
      body = {
        :scheduling => { :enabled => true },
        :index_name => ingestion_index_name
      }
      response = client.index(:index => CONNECTORS_INDEX, :body => body)
      id = response['_id']
      Utility::Logger.info("Successfully registered connector #{index_name} with ID #{id}")
    end

    def self.load_connector_settings(connector_package_id)
      client.get(:index => CONNECTORS_INDEX, :id => connector_package_id).with_indifferent_access
    end

    def self.update_connector_configuration(connector_package_id, configuration)
      body = {
        :doc => {
          :configuration => configuration
        }
      }

      client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
      Utility::Logger.info("Successfully updated configuration for connector #{connector_package_id}")
    end

    def self.claim_job(connector_package_id)
      body = {
        :doc => {
          :sync_now => false,
          :sync_status => Connectors::SyncStatus::IN_PROGRESS,
          :last_synced => Time.now
        }
      }

      client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
      Utility::Logger.info("Successfully claimed job for connector #{connector_package_id}")
    end

    def self.complete_sync(connector_package_id, error)
      body = {
        :doc => {
          :sync_status => error.nil? ? Connectors::SyncStatus::COMPLETED : Connectors::SyncStatus::FAILED,
          :sync_error => error,
          :last_synced => Time.now
        }
      }

      client.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)

      if error
        Utility::Logger.info("Failed to sync for connector #{connector_package_id} with error #{error}")
      else
        Utility::Logger.info("Successfully synced for connector #{connector_package_id}")
      end
    end

    def self.client
      Utility::EsClient.client
    end
  end
end
