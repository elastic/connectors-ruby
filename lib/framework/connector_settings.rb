#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Framework
  class ConnectorSettings
    def self.fetch(connector_package_id)
      es_response = ElasticConnectorActions.load_connector_settings(connector_package_id)

      new(es_response)
    end

    def id
      @elasticsearch_response[:_id]
    end

    def [](index)
      @elasticsearch_response[:_source][index]
    end

    def configuration
      @elasticsearch_response[:_source][:configuration]
    end

    def scheduling_settings
      self['scheduling']
    end

    def configuration_initialized?
      return false if configuration.nil?
      configuration.present?
    end

    def update_configuration(configuration)
      ElasticConnectorActions.update_connector_configuration(id, configuration) # TODO: I don't like that it's hidden here now

      @elasticsearch_response[:_source][:configuration] = configuration
    end

    private

    def initialize(es_response)
      @elasticsearch_response = es_response
    end
  end
end
