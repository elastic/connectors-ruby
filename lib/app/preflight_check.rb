#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/version'
require 'utility'
require 'faraday'

module App
  class PreflightCheck
    class CheckFailure < StandardError; end
    class UnhealthyCluster < StandardError; end

    STARTUP_RETRY_INTERVAL = 5
    STARTUP_RETRY_TIMEOUT = 600

    class << self
      def run!
        check_es_connection!
        check_es_version!
        check_system_indices!
      end

      private

      #-------------------------------------------------------------------------------------------------
      # Checks to make sure we can connect to Elasticsearch and make API requests to it
      def check_es_connection!
        check_es_connection_with_retries!(
          :retry_interval => STARTUP_RETRY_INTERVAL,
          :retry_timeout => STARTUP_RETRY_TIMEOUT
        )
      end

      #-------------------------------------------------------------------------------------------------
      # Ensures that the version of Elasticsearch is compatible with connector service
      def check_es_version!
        info = client.info
        version = info.dig('version', 'number')
        fail_check!("Cannot retrieve version from Elasticsearch response:\n#{info.to_json}") unless version

        if match_es_version?(version)
          Utility::Logger.info("Connector service version (#{App::VERSION}) matches Elasticsearch version (#{version}).")
        else
          fail_check!("Connector service (#{App::VERSION}) is required to run with the same major and minor version of Elasticsearch (#{version}).")
        end
      end

      #-------------------------------------------------------------------------------------------------
      # Ensures that the required system indices of connector service exist
      def check_system_indices!
        check_system_indices_with_retries!(
          :retry_interval => STARTUP_RETRY_INTERVAL,
          :retry_timeout => STARTUP_RETRY_TIMEOUT
        )
      end

      def check_es_connection_with_retries!(retry_interval:, retry_timeout:)
        started_at = Time.now

        begin
          response = client.cluster.health
          Utility::Logger.info('Successfully connected to Elasticsearch')
          case response['status']
          when 'green'
            Utility::Logger.info('Elasticsearch is running and healthy.')
          when 'yellow'
            Utility::Logger.warn('Elasticsearch is running but the status is yellow.')
          when 'red'
            raise UnhealthyCluster, 'Elasticsearch is running but unhealthy.'
          else
            raise UnhealthyCluster, "Unexpected cluster status: #{response['status']}"
          end
        rescue *Utility::AUTHORIZATION_ERRORS => e
          Utility::ExceptionTracking.log_exception(e)

          fail_check!("Elasticsearch returned 'Unauthorized' response. Check your authentication details. Terminating...")
        rescue *App::RETRYABLE_CONNECTION_ERRORS => e
          Utility::Logger.warn('Could not connect to Elasticsearch. Make sure it is running and healthy.')
          Utility::Logger.debug("Error: #{e.full_message}")

          sleep(retry_interval)
          time_elapsed = Time.now - started_at
          retry if time_elapsed < retry_timeout

          # If we ran out of time, there is not much we can do but shut down
          fail_check!("Could not connect to Elasticsearch after #{time_elapsed.to_i} seconds. Terminating...")
        end
      end

      def match_es_version?(es_version)
        parse_minor_version(App::VERSION) == parse_minor_version(es_version)
      end

      def parse_minor_version(version)
        version.split('.').slice(0, 2).join('.')
      end

      def check_system_indices_with_retries!(retry_interval:, retry_timeout:)
        started_at = Time.now
        loop do
          if client.indices.exists?(:index => Utility::Constants::CONNECTORS_INDEX) && client.indices.exists?(:index => Utility::Constants::JOB_INDEX)
            Utility::Logger.info("Found system indices #{Utility::Constants::CONNECTORS_INDEX} and #{Utility::Constants::JOB_INDEX}.")
            return
          end
          Utility::Logger.warn('Required system indices for connector service don\'t exist. Make sure to run Kibana first to create system indices.')
          sleep(retry_interval)
          time_elapsed = Time.now - started_at
          if time_elapsed > retry_timeout
            fail_check!("Could not find required system indices after #{time_elapsed.to_i} seconds. Terminating...")
          end
        end
      end

      def client
        @client ||= Utility::EsClient.new(App::Config[:elasticsearch])
      end

      def fail_check!(message)
        raise CheckFailure, message
      end
    end
  end

  RETRYABLE_CONNECTION_ERRORS = [
      ::Faraday::ConnectionFailed,
      ::Faraday::ClientError,
      ::Errno::ECONNREFUSED,
      ::SocketError,
      ::Errno::ECONNRESET,
      App::PreflightCheck::UnhealthyCluster,
      ::HTTPClient::KeepAliveDisconnected
  ]
end
