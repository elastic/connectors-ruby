#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'framework'
require 'utility'

module App
  module Connector
<<<<<<< HEAD
    CONNECTORS_INDEX = '.elastic-connectors'
    QUERY_SIZE = 20
=======
>>>>>>> 60e5fbd (WIP 2)
    POLL_IDLING = 60

    @client = Utility::EsClient.new

    class << self

      def start!
        pre_flight_check

        ensure_index_exists(CONNECTORS_INDEX)

        Utility::Logger.info('Starting to process jobs...')
        start_polling_jobs
      end

      def initiate_sync
        connector = current_connector_config
        sync_now = connector&.dig('_source', 'sync_now')
        unless sync_now.present?
          body = {
            :doc => {
              :scheduling => { :enabled => true },
              :sync_now => true
            }
          }
          @client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
          Utility::Logger.info("Successfully pushed sync_now flag for connector #{connector['_id']}")
        end
        start! unless running?
      end

      def register_connector(index_name)
        connector_config = current_connector_config
        id = connector_config&.fetch('_id', nil)
        if connector_config.nil?
          ensure_index_exists(index_name)
          body = {
            :scheduling => { :enabled => true },
            :index_name => index_name
          }
          response = @client.index(:index => CONNECTORS_INDEX, :body => body)
          id = response['_id']
          Utility::Logger.info("Successfully registered connector #{index_name} with ID #{id}")
        end
        id
      end

      def current_connector_config
        response = @client.get(:index => CONNECTORS_INDEX, :id => App::Config['connector_package_id'], :ignore => 404)
        response['found'] ? response : nil
      end

      private

      def pre_flight_check
        raise "#{App::Config['service_type']} is not a supported connector" unless Connectors::REGISTRY.registered?(App::Config['service_type'])
      end

      def start_polling_jobs
        loop do
          connector_instance = Connectors::REGISTRY.connector_class(App::Config['service_type']).new
          connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])

          connector_settings.update_configuration(connector_instance.configurable_fields) unless connector_settings.configuration_initialized?

          connector = Framework::ConnectorRunner.new(
            connector_settings: connector_settings,
            connector_instance: connector_instance
          )

          connector.execute
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
        ensure
          Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds")
          sleep(POLL_IDLING)
        end
      end

      def ensure_index_exists(index_name)
        @client.indices.create(index: index_name) unless @client.indices.exists?(index: index_name)
      end
    end
  end
end
