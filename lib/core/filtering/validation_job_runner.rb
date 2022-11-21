#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/connector_status'
require 'connectors/registry'
require 'core/filtering'

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

        validation_result = @connector_class.validate_filtering(@connector_settings.filtering[:draft])

        # currently only used for connectors -> DEFAULT domain can be assumed (will be changed with the integration of crawler)
        ElasticConnectorActions.update_filtering_validation(@connector_settings.id, { Core::Filtering::DEFAULT_DOMAIN => validation_result })

        @validation_finished = true
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e)
        validation_failed_result = { :state => Core::Filtering::ValidationStatus::INVALID,
                                     :errors => [
                                       { :ids => [], :messages => ['Unknown problem occurred while validating, see logs for details.'] }
                                     ] }
        ElasticConnectorActions.update_filtering_validation(@connector_settings.id, { DEFAULT_DOMAIN => validation_failed_result })
      ensure
        if !@validation_finished && !@status[:error].present?
          @status[:error] = 'Validation thread did not finish execution. Check connector logs for more details.'
        end

        if @status[:error]
          Utility::Logger.warn("Failed to validate filtering for connector #{@connector_settings.id} with error '#{@status[:error]}'.")
        else
          Utility::Logger.info("Successfully validated filtering for connector #{@connector_settings.id}.")
        end
      end
    end
  end
end
