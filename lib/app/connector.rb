#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support'
require 'concurrent'
require 'connectors'
require 'cron_parser'
require 'utility'

module App
  module Connector
    SYNC_JOB_POOL = Concurrent::ThreadPoolExecutor.new(
      :min_threads => 8,
      :max_threads => 8,
      :max_queue => 1_000,
      :fallback_policy => :abort
    )
    CONNECTORS_INDEX = '.elastic-connectors'
    QUERY_SIZE = 20
    POLL_IDLING = 60

    @running = Concurrent::AtomicBoolean.new(false)

    class << self

      def start!
        pre_flight_check
        ensure_index_exists
        running!

        Utility::Logger.info('Starting to process jobs...')
        start_polling_jobs
      end

      def running?
        running.true?
      end

      def sync_now
        start! unless running?
        connector = current_connector_config
        sync_now = connector['_source']['sync_now']
        unless sync_now.present?
          body = {
            :doc => {
              :scheduling => { :enabled => true },
              :sync_now => true
            }
          }
          Utility::EsClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
          Utility::Logger.info("Successfully pushed sync_now flag for connector #{connector['_id']}")
        end
      end

      private

      attr_reader :running, :connector_klass

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

        SYNC_JOB_POOL.post do
          connector_klass.new.sync_content(connector) do |error|
            complete_sync(connector, error)
          end
        end
      end

      def current_connector_config
        Utility::EsClient.get(:index => CONNECTORS_INDEX, :id => App::Config['connector_package_id'])
      end

      def ensure_index_exists
        Utility::EsClient.indices.create(index: CONNECTORS_INDEX) unless Utility::EsClient.indices.exists?(index: CONNECTORS_INDEX)
      end

      def update_config_if_necessary(connector)
        configuration = connector['_source']['configuration']
        if configuration.nil? || configuration.empty?
          body = {
            :doc => {
              :configuration => connector_klass.new.configurable_fields
            }
          }
          Utility::EsClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
          Utility::Logger.info("Successfully updated configuration for connector #{connector['_id']}")
        end
      end

      def should_sync?(connector)
        return false unless connector['_source']['scheduling']['enabled']
        return true if connector['_source']['sync_now']

        last_synced = connector['_source']['last_synced']
        return true if last_synced.nil? || last_synced.empty?

        last_synced = Time.parse(last_synced)
        sync_interval = connector['_source']['scheduling']['interval']
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

        Utility::EsClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
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

        Utility::EsClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
        if error
          Utility::Logger.info("Failed to sync for connector #{connector['_id']} with error #{error}")
        else
          Utility::Logger.info("Successfully synced for connector #{connector['_id']}")
        end
      end
    end
  end
end
