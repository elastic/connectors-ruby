#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/output_sink'
require 'utility/exception_tracking'
require 'utility/errors'
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

      def initialize(configuration: {})
        @configuration = configuration.dup || {}
      end

      def yield_documents(job_description = {}); end

      def filtering_present?(rules, advanced_config)
        rules_present?(rules) || advanced_config_present?(advanced_config)
      end

      def advanced_config_present?(advanced_config)
        !advanced_config.nil? && !advanced_config.empty?
      end

      def rules_present?(rules)
        !rules.nil? && !rules.empty?
      end

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
    end
  end
end
