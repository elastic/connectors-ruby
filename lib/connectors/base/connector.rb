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

      attr_reader :active_rules, :advanced_filter_config

      def initialize(configuration: {})
        @configuration = configuration.dup || {}

        @active_rules = extract_active_rules(@configuration)
        @advanced_filter_config = extract_advanced_filter_config(@configuration)
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
        active_rules_present? || advanced_filter_config_present
      end

      def advanced_filter_config_present
        !@advanced_filter_config.nil? && !@advanced_filter_config.empty?
      end

      def active_rules_present?
        !@active_rules.nil? && !@active_rules.empty?
      end

      private

      def extract_active_rules(job_description)
        Utility::Common.return_if_present(job_description.dig(:filtering, :active, :rules), [])
      end

      def extract_advanced_filter_config(job_description)
        Utility::Common.return_if_present(job_description.dig(:filtering, :active, :advanced_config), {})
      end
    end
  end
end
