#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'connectors'
require 'cron_parser'
require 'utility'

module App
  module Connector
    CONNECTORS_INDEX = '.elastic-connectors'
    QUERY_SIZE = 20
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

      attr_reader :connector_klass

      def running!
        raise 'The connector app is already running!' unless running.make_true
      end

      def pre_flight_check
        @connector_klass = Connectors::REGISTRY.connector_class(App::Config['service_type'])
        raise "#{App::Config['service_type']} is not a supported connector" if @connector_klass.nil?
      end

      def start_polling_jobs
        loop do
          polling_jobs
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e, 'Sync failed due to unexpected error.')
        ensure
          Utility::Logger.info("Sleeping for #{POLL_IDLING} seconds")
          sleep(POLL_IDLING)
        end
      end

      def polling_jobs
        connector = current_connector_config
        update_config_if_necessary(connector)

        return unless should_sync?(connector)

        Utility::Logger.info("Starting to sync for connector #{connector['_id']}")
        claim_job(connector)

        connector_klass.new.sync_content(connector) do |error|
          complete_sync(connector, error)
        end
      end

      def ensure_index_exists(index_name)
        @client.indices.create(index: index_name) unless @client.indices.exists?(index: index_name)
      end

      def ensure_index_exists(index_name)
        @client.indices.create(index: index_name) unless @client.indices.exists?(index: index_name)
      end

      def update_config_if_necessary(connector)
        configuration = connector&.dig('_source', 'configuration')
        if configuration.nil? || configuration.empty?
          body = {
            :doc => {
              :configuration => connector_klass.new.configurable_fields
            }
          }
          if connector.present?
            @client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
          else
            raise "Connector config not found: #{connector}"
          end
          Utility::Logger.info("Successfully updated configuration for connector #{connector['_id']}")
        end
      end

      def should_sync?(connector)
        return false unless connector.dig('_source', 'scheduling', 'enabled')
        return true if connector.dig('_source', 'sync_now')

        last_synced = connector.dig('_source', 'last_synced')
        return true if last_synced.nil? || last_synced.empty?

        last_synced = Time.parse(last_synced)
        sync_interval = connector.dig('_source', 'scheduling', 'interval')
        cron_parser = cron_parser(sync_interval)
        cron_parser && cron_parser.next(last_synced) < Time.now
      end

      def cron_parser(cronline)
        CronParser.new(cronline)
      rescue ArgumentError => e
        Utility::Logger.error("Fail to parse cronline #{cronline}. Error: #{e.message}")
        nil
      end

      def claim_job(connector)
        body = {
          :doc => {
            :sync_now => false,
            :sync_status => Connectors::SyncStatus::IN_PROGRESS,
            :last_synced => Time.now
          }
        }

        @client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
        Utility::Logger.info("Successfully claimed job for connector #{connector['_id']}")
      end

      def complete_sync(connector, error = nil)
        body = {
          :doc => {
            :sync_status => error.nil? ? Connectors::SyncStatus::COMPLETED : Connectors::SyncStatus::FAILED,
            :sync_error => error,
            :last_synced => Time.now
          }
        }

        @client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
        if error
          Utility::Logger.info("Failed to sync for connector #{connector['_id']} with error #{error}")
        else
          Utility::Logger.info("Successfully synced for connector #{connector['_id']}")
        end
      end
    end
  end
end
