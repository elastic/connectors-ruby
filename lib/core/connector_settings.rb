#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'
require 'connectors/connector_status'
require 'utility/logger'

module Core
  class ConnectorSettings
    # Error Classes
    class ConnectorNotFoundError < StandardError; end

    def self.fetch(connector_id)
      es_response = ElasticConnectorActions.get_connector(connector_id)
        .with_indifferent_access

      raise ConnectorNotFoundError.new("Connector with id=#{connector_id} was not found.") unless es_response[:found]
      new(es_response)
    end

    def id
      @elasticsearch_response[:_id]
    end

    def [](property_name)
      # TODO: handle not found
      @elasticsearch_response[:_source][property_name]
    end

    def index_name
      self[:index_name]
    end

    def connector_status
      self[:status]
    end

    def connector_status_allows_sync?
      Connectors::ConnectorStatus::STATUSES_ALLOWING_SYNC.include?(connector_status)
    end

    def service_type
      self[:service_type]
    end

    def configuration
      self[:configuration]
    end

    def scheduling_settings
      self[:scheduling]
    end

    def configuration_initialized?
      configuration.present?
    end

    def initialize_configuration(configuration)
      # TODO: actually check it on the level lower, so that desync does not happen if configuration was updated elsewhere
      raise 'Configuration is already initialized!' if configuration_initialized?

      ElasticConnectorActions.update_connector_configuration(id, configuration) # TODO: I don't like that it's hidden here now

      # We want to set connector to CONFIGURED status if all configurable fields have default values
      new_connector_status = if configuration.values.all? { |setting| setting[:value] }
                               Connectors::ConnectorStatus::CONFIGURED
                             else
                               Connectors::ConnectorStatus::NEEDS_CONFIGURATION
                             end

      ElasticConnectorActions.update_connector_status(id, new_connector_status)

      @elasticsearch_response[:_source][:configuration] = configuration
      @elasticsearch_response[:status] = new_connector_status
    end

    private

    def initialize(es_response)
      @elasticsearch_response = es_response
    end
  end
end
