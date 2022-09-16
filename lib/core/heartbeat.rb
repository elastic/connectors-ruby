#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'
require 'core/connector_settings'
require 'core/elastic_connector_actions'

module Core
  class Heartbeat
    class << self
      def send(connector_settings)
        doc = {
            :last_seen => Time.now
        }
        if connector_settings.connector_status_allows_sync?
          connector_instance = Connectors::REGISTRY.connector(connector_settings.service_type, connector_settings.configuration)
          doc[:status] = connector_instance.is_healthy? ? Connectors::ConnectorStatus::CONNECTED : Connectors::ConnectorStatus::ERROR
          message = "Health check for 3d party service failed for connector [#{connector_id}], service type [#{service_type}]. Check the application logs for more information."
          doc[:error] = doc[:status] == Connectors::ConnectorStatus::ERROR ? message : nil
        end

        Core::ElasticConnectorActions.update_connector_fields(connector_settings.id, doc)
      end
    end
  end
end
