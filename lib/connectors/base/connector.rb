#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/ingestion'
require 'utility'
require 'utility/filtering'
require 'app/config'
require 'active_support/core_ext/hash/indifferent_access'

module Connectors
  module Base
    class Connector
      def self.display_name
        raise 'Not implemented for this connector'
      end

      # Used as a framework util method, don't override
      def self.configurable_fields_indifferent_access
        configurable_fields.with_indifferent_access
      end

      def self.configurable_fields
        {}
      end

      def self.service_type
        raise 'Not implemented for this connector'
      end

      def self.kibana_features
        [
          Utility::Constants::FILTERING_RULES_FEATURE,
          Utility::Constants::FILTERING_ADVANCED_FEATURE
        ]
      end

      def self.validate_filtering(_filtering = {})
        raise 'Not implemented for this connector'
      end

      attr_reader :rules, :advanced_filter_config

      def initialize(configuration: {}, job_description: {})
        @configuration = configuration.dup || {}
        @job_description = job_description&.dup || {}

        filtering = Utility::Filtering.extract_filter(@job_description[:filtering])

        @rules = filtering[:rules] || []
        @advanced_filter_config = filtering[:advanced_snippet] || {}
      end

      def yield_documents; end

      def do_health_check
        raise 'Not implemented for this connector'
      end

      def do_health_check!
        do_health_check
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Connector for service #{self.class.service_type} failed the health check for 3rd-party service.")
        raise Utility::HealthCheckFailedError.new, e.message
      end

      def is_healthy?
        do_health_check

        true
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Connector for service #{self.class.service_type} failed the health check for 3rd-party service.")
        false
      end

      def filtering_present?
        @advanced_filter_config.present? && !@advanced_filter_config.empty? || @rules.present?
      end

      def metadata
        {}
      end
    end
  end
end
