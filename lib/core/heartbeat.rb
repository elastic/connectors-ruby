#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'

module Core
  class Heartbeat
    class << self
      def send(connector_id, service_type)
        connector_settings = Core::ConnectorSettings.fetch(connector_id)

        doc = {
          :last_seen => Time.now
        }

        if connector_settings.connector_status == Connectors::ConnectorStatus::CREATED
          connector_class = Connectors::REGISTRY.connector_class(service_type)
          doc[:configuration] = connector_class.configurable_fields
          doc[:status] = Connectors::ConnectorStatus::NEEDS_CONFIGURATION
        elsif connector_settings.connector_status_allows_sync?
          connector_instance = Connectors::REGISTRY.connector(service_type, connector_settings.configuration)
          doc[:status] = connector_instance.source_status[:status] == 'OK' ? Connectors::ConnectorStatus::CONNECTED : Connectors::ConnectorStatus::ERROR
        end

        ElasticConnectorActions.update_connector_fields(connector_id, doc)
      end
    end
  end
end
