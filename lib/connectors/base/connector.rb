#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'app/config'
require 'bson'
require 'connectors/base/advanced_snippet_validator'
require 'core/ingestion'
require 'core/filtering/transform/filter_transformer_facade'
require 'connectors/tolerable_error_helper'
require 'core/filtering/validation_status'
require 'utility'
require 'utility/filtering'

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

      def self.advanced_snippet_validator
        AdvancedSnippetValidator
      end

      def self.filter_transformers
        {
          'advanced_snippet' => [],
          'rules' => []
        }
      end

      def self.validate_filtering(filtering = {})
        # nothing to validate
        return { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] } unless filtering.present?

        filter = Utility::Filtering.extract_filter(filtering)
        filter = Core::Filtering::Transform::FilterTransformerFacade.new(filter, filter_transformers['rules'], filter_transformers['advanced_snippet']).transform

        advanced_snippet = filter.dig(:advanced_snippet, :value)

        snippet_validator_instance = advanced_snippet_validator.new(advanced_snippet)

        snippet_validator_instance.is_snippet_valid?
      end

      attr_reader :rules, :advanced_filter_config

      def initialize(configuration: {}, job_description: nil)
        error_monitor = Utility::ErrorMonitor.new
        @tolerable_error_helper = Connectors::TolerableErrorHelper.new(error_monitor)

        @configuration = job_description&.configuration&.dup || configuration&.dup || {}
        @job_description = job_description&.dup

        filter = Utility::Filtering.extract_filter(@job_description&.filtering)
        filter = Core::Filtering::Transform::FilterTransformerFacade.new(filter, self.class.filter_transformers['rules'], self.class.filter_transformers['advanced_snippet']).transform

        @rules = filter[:rules] || []
        @advanced_filter_config = filter[:advanced_snippet] || {}
      end

      def yield_documents; end

      def yield_with_handling_tolerable_errors(identifier: nil, &block)
        @tolerable_error_helper.yield_single_document(identifier: identifier, &block)
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

      def filtering_present?
        @advanced_filter_config.present? && !@advanced_filter_config.empty? || @rules.present?
      end

      def metadata
        {}
      end
    end
  end
end
