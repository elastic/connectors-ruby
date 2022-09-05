#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/version'
require 'utility/logger'

module App
  class PreflightCheck
    class CheckFailure < StandardError; end

    CONNECTORS_INDEX = '.elastic-connectors'
    JOB_INDEX = '.elastic-connectors-sync-jobs'

    def self.run!
      App::PreflightCheck.new.run!
    end

    def run!
      check_es_connection!
      check_es_version!
      check_system_indices!
    end

    private

    #-------------------------------------------------------------------------------------------------
    # Checks to make sure we can connect to Elasticsearch and make API requests to it
    def check_es_connection!
      response = client.cluster.health
      case response['status']
      when 'green'
        Utility::Logger.info('Elasticsearch backend is running and healthy.')
      when 'yellow'
        Utility::Logger.warn('Elasticsearch backend is running but the status is yellow.')
      when 'red'
        fail_check!('Elasticsearch backend is running but is unhealthy.')
      else
        fail_check!("Unexpected cluster status: #{response['status']}")
      end
    rescue StandardError
      fail_check!('Could not connect to Elasticsearch backend. Make sure it is running and healthy.')
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
      unless client.indices.exists?(:index => CONNECTORS_INDEX) && client.indices.exists?(:index => JOB_INDEX)
        fail_check!('Required system indices for connector service don\'t exist. Make sure to run Kibana first to create system indices.')
      end
    end

    def match_es_version?(es_version)
      parse_minor_version(App::VERSION) == parse_minor_version(es_version)
    end

    def parse_minor_version(version)
      version.split('.').slice(0, 2).join('.')
    end

    def client
      @client ||= Utility::EsClient.new(App::Config[:elasticsearch])
    end

    def fail_check!(message)
      raise CheckFailure, message
    end
  end
end
