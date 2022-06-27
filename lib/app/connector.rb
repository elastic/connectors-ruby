#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

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

      def start_polling_jobs
        loop do
          polling_jobs
        rescue StandardError => e
          Utility::Logger.error("Error happened during sync. error: #{e.message}")
          raise
        ensure
          sleep(60)
        end
      end

      def polling_jobs
        from = 0
        loop do
          response = Utility::ElasticsearchClient.search(:index => CONNECTORS_INDEX, :from => from, :size => QUERY_SIZE)
          connectors = response['hits']['hits']

          connectors.each do |connector|
            service_type = connector['_source']['service_type']

            next unless should_sync?(connector)
            claim_job(connector)

            connector_class = Connectors::REGISTRY.connector_class(service_type)
            unless connector_class
              complete_sync(connector, "#{service_type} is not a supported connector.")
              next
            end

            SYNC_JOB_POOL.post do
              connector_class.new.sync(connector) do |error|
                complete_sync(connector, error)
              end
            end
          end

          break if connectors.count == 0
          from += connectors.count
        end
      end

      def should_sync?(connector)
        sync_now = connector['_source']['sync_now']
        last_synced = connector['_source']['last_synced']
        sync_enabled = connector['_source']['scheduling']['enabled']
        sync_interval = connector['_source']['scheduling']['interval']

        return false unless sync_enabled
        return true if sync_now

        cron_parser = cron_parser(sync_interval)
        cron_parser && cron_parser.next(last_synced).utc < Time.now.utc
      end

      def cron_parser(cronline)
        CronParser.new(cronline)
      rescue ArgumentError => e
        Utility.Logger.error("Fail to parse cronline #{cronline}. Error: #{e.message}")
        nil
      end

      def claim_job(connector)
        body = {
          :doc => {
            :sync_now => false,
            :sync_status => Connectors::SyncStatus::IN_PROGRESS,
            :last_synced => Time.now.utc,
            :updated_at => Time.now.utc
          }
        }

        Utility::ElasticsearchClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
      end

      def complete_sync(connector, error = nil)
        body = {
          :doc => {
            :sync_status => error.nil? ? Connectors::SyncStatus::COMPLETED : Connectors::SyncStatus::FAILED,
            :last_synced => Time.now.utc,
            :updated_at => Time.now.utc
          }
        }
        body[:sync_error] = error if error

        Utility::ElasticsearchClient.update(:index => connector['_index'], :id => connector['_id'], :body => body)
      end
    end
  end
end
