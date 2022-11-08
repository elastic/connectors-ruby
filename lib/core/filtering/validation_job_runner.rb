#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'

module Core
  module Filtering
    class ValidationJobRunner
      def initialize(connector_settings)
        @connector_settings = connector_settings
        @connector_class = Connectors::REGISTRY.connector_class(connector_settings.service_type)
        @validation_finished = false
        @status = { :error => nil }
      end

      def execute
        Utility::Logger.info("Starting a validation job for connector #{@connector_settings.id}.")

        validation_result = @connector_class.validate_filtering(@connector_settings.filtering)

        # currently only used for connectors -> DEFAULT domain can be assumed (will be changed with the integration of crawler)
        ElasticConnectorActions.update_filtering_validation(@connector_settings.id, { 'DEFAULT' => validation_result })

        @validation_finished = true
      rescue StandardError => e
        @status[:error] = e.message
        Utility::ExceptionTracking.log_exception(e)
        ElasticConnectorActions.update_connector_status(@connector_settings.id, Connectors::ConnectorStatus::ERROR, Utility::Logger.abbreviated_message(e.message))
      ensure
        if !@validation_finished && !@status[:error].present?
          @status[:error] = 'Validation thread did not finish execution. Check connector logs for more details.'
        end

        if @status[:error]
          Utility::Logger.info("Failed to validate filtering for connector #{@connector_settings.id} with error '#{@status[:error]}'.")
        else
          Utility::Logger.info("Successfully validated filtering for connector #{@connector_settings.id}.")
        end
      end
    end
  end
end
