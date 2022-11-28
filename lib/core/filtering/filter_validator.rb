#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/validation_status'
require 'core/filtering/processing_stage'
require 'utility/logger'

module Core
  module Filtering
    class FilterValidator

      ADVANCED_SNIPPET = 'Advanced Snippet'
      SIMPLE_RULES = 'Simple Rules'

      def initialize(snippet_validator_classes: [], rules_validator_classes: [], rules_pre_processing_active: false)
        @snippet_validators_classes = {
            'classes' => extract_advanced_snippet_validators(snippet_validator_classes),
            'type' => ADVANCED_SNIPPET
          }

        @rules_validator_classes = {
            'classes' => extract_simple_rule_validators(rules_validator_classes, rules_pre_processing_active),
            'type' => SIMPLE_RULES
        }
      end

      def is_filter_valid(filter = {})
        return { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] } unless filter.present?

        snippet_validation_result = execute_validation(@snippet_validators_classes, filter)
        log_validation_result(snippet_validation_result, ADVANCED_SNIPPET)

        rules_validation_result = execute_validation(@rules_validator_classes, filter)
        log_validation_result(rules_validation_result, SIMPLE_RULES)

        merge_validation_results(snippet_validation_result, rules_validation_result)
      end

      private

      def log_validation_result(validation_result, validator_type)
        Utility::Logger.info("Filtering #{validator_type} validation result: #{validation_result[:state]}")
        if validation_result[:errors].present?
          validation_result[:errors].each do |error|
            Utility::Logger.warn("Filtering #{validator_type} validation error for: '#{error[:ids]}': '#{error[:messages]}'")
          end
        end
      end

      def merge_validation_results(*validation_results)
        merged_result = { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }

        validation_results.each do |validation_result|
          merged_result[:state] = Core::Filtering::ValidationStatus::INVALID if validation_result[:state] == Core::Filtering::ValidationStatus::INVALID
          merged_result[:errors].push(*validation_result[:errors]) if validation_result[:errors].present?
        end

        merged_result
      end

      def execute_validation(validators, filter)
        validation_results = []

        validator_type = validators['type']
        advanced_snippet = filter.dig('advanced_snippet', 'value')

        validators['classes'].each do |validator_class|
          case validator_type
          when ADVANCED_SNIPPET
            validation_result = validator_class.new(advanced_snippet).is_snippet_valid
          when SIMPLE_RULES
            validation_result = validator_class.new(filter['rules']).are_rules_valid
          else
            raise "Unknown validator: #{validator_type}"
          end

          validation_results.push(validation_result) if validation_result[:state] == Core::Filtering::ValidationStatus::INVALID
        end

        merge_validation_results(*validation_results)
      end

      def extract_advanced_snippet_validators(snippet_validators)
        snippet_validators.is_a?(Array) ? snippet_validators : [snippet_validators]
      end

      def extract_simple_rule_validators(rule_validators, pre_processing_active)
        return rule_validators if rule_validators.is_a?(Array)

        common_validators = rule_validators[Core::Filtering::ProcessingStage::ALL] || []
        pre_validators = rule_validators[Core::Filtering::ProcessingStage::PRE] || []
        post_validators = rule_validators[Core::Filtering::ProcessingStage::POST] || []

        # post processing validation will always be executed
        pre_processing_active ? common_validators + pre_validators + post_validators : common_validators + post_validators
      end
    end
  end
end
