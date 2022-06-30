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

    def self.load_connector_settings(connector_package_id)
      Utility::EsClient.get(:index => CONNECTORS_INDEX, :id => connector_package_id).with_indifferent_access
    end

    def self.update_connector_configuration(connector_package_id, configuration)
      body = {
        :doc => {
          :configuration => configuration
        }
      }

      Utility::EsClient.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
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

      Utility::EsClient.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)
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

      Utility::EsClient.update(:index => CONNECTORS_INDEX, :id => connector_package_id, :body => body)

      if error
        Utility::Logger.info("Failed to sync for connector #{connector_package_id} with error #{error}")
      else
        Utility::Logger.info("Successfully synced for connector #{connector_package_id}")
      end
    end
  end
end
