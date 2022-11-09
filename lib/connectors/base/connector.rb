#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/output_sink'
require 'utility'
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

      attr_reader :rules, :advanced_filter_config

      def initialize(configuration: {}, job_description: {})
        @configuration = configuration.dup || {}
        @job_description = job_description&.dup || {}

        filter = get_filter(@job_description[:filtering])

        @rules = Utility::Common.return_if_present(filter[:rules], [])
        @advanced_filter_config = Utility::Common.return_if_present(filter[:advanced_snippet], {})
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

      private

      def get_filter(filtering)
        # assume for now, that first object in filtering array or a filter object itself is the only filtering object
        filter = filtering.is_a?(Array) ? filtering[0] : filtering

        filter.present? ? filter : {}
      end
    end
  end
end
