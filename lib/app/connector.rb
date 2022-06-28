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
        running!

        Utility::Logger.info('Starting to process jobs.')
        start_polling_jobs
      end

      def running?
        running.true?
      end

      private

      attr_reader :running

      def running!
        raise 'The connector app is already running!' unless running.make_true
      end

      def es_client
        @es_client ||= Utility::EsClientFactory.client
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
        from = 0
        loop do
          response = es_client.search(:index => CONNECTORS_INDEX, :from => from, :size => QUERY_SIZE)
          connectors = response['hits']['hits']

          connectors.each do |connector|
            service_type = connector['_source']['service_type']
            Utility::Logger.info("Found connector with service type #{service_type}")
            next unless should_sync?(connector)
            Utility::Logger.info("Starting to sync for #{service_type}")
            claim_job(connector)

            connector_class = Connectors::REGISTRY.connector_class(service_type)
            unless connector_class
              complete_sync(connector, "#{service_type} is not a supported connector.")
              next
            end

            SYNC_JOB_POOL.post do
              connector_class.new(connector['_source']['index_name']).sync(connector) do |error|
                complete_sync(connector, error)
              end
            end
          end

          break if connectors.count == 0
          from += connectors.count
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

        es_client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
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

        es_client.update(:index => connector['_index'], :id => connector['_id'], :body => body)
        if error
          Utility::Logger.info("Failed to sync for connector #{connector['_id']} with error #{error}")
        else
          Utility::Logger.info("Successfully synced for connector #{connector['_id']}")
        end
      end
    end
  end
end
