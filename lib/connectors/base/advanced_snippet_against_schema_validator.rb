#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'utility/logger'
require 'connectors/base/advanced_snippet_validator'
require 'core/filtering/validation_status'

module Connectors
  module Base
    class AdvancedSnippetAgainstSchemaValidator < Connectors::Base::AdvancedSnippetValidator

      MAX_RECURSION_DEPTH = 50

      def initialize(advanced_snippet, schema)
        super(advanced_snippet)
        @schema = schema
      end

      def is_snippet_valid?
        validate_against_schema(@schema, @advanced_snippet)
      end

      private

      def validate_against_schema(config_schema, advanced_snippet, recursion_depth = 0)
        # Prevent unintentional/intentional SystemStackErrors/crashes
        return unexpected_error if exceeded_recursion_depth?(recursion_depth)

        return valid_snippet if config_schema.nil? || config_schema.empty?

        return fields_constraint_violation if fields_constraints_violated?(config_schema, advanced_snippet)

        schema_fields = config_schema[:fields].is_a?(Hash) ? config_schema.dig(:fields, :values) : config_schema[:fields]
        snippet_field_names = advanced_snippet&.keys&.map(&:to_s)
        schema_field_names = schema_fields.map { |field| field[:name] }

        return unexpected_field(schema_field_names, snippet_field_names) if unexpected_field_present?(snippet_field_names, schema_field_names)

        schema_fields.each do |field|
          name = field[:name]
          type = field[:type]
          optional = field[:optional] || false

          snippet_field_value = advanced_snippet.with_indifferent_access[name]

          next if optional && (snippet_field_value.nil? || !snippet_field_value.present?)

          return wrong_names(snippet_field_names, name) unless snippet_field_names.include?(name)

          return wrong_type(name, type, snippet_field_value) if type_error_present?(type, snippet_field_value)

          if field[:fields].present?
            validation_result = validate_against_schema(field, snippet_field_value, recursion_depth + 1)

            return validation_result unless validation_result[:is_valid]
          end
        end

        valid_snippet
      end

      def fields_constraints_violated?(config_schema, advanced_snippet)
        return false unless config_schema[:fields].is_a?(Hash)

        constraints = config_schema.dig(:fields, :constraints)
        constraints = constraints.is_a?(Array) ? constraints : [constraints]

        constraints.each do |constraint|
          return true unless constraint.call(advanced_snippet)
        end

        false
      end

      def type_error_present?(schema_type, snippet_value)
        return !schema_type.call(snippet_value) if schema_type.is_a?(Proc)

        return true unless snippet_value.is_a?(schema_type)

        false
      end

      def exceeded_recursion_depth?(recursion_depth)
        if recursion_depth >= MAX_RECURSION_DEPTH
          Utility::Logger.warn("Recursion depth for filtering validation exceeded. (Max recursion depth: #{MAX_RECURSION_DEPTH})")
          return true
        end

        false
      end

      def unexpected_field_present?(actual_field_names, expected_field_names)
        difference = actual_field_names - expected_field_names

        # we have field names, which we didn't expect
        !difference.empty?
      end

      def valid_snippet
        {
          :state => Core::Filtering::ValidationStatus::VALID,
          :errors => []
        }
      end

      def unexpected_field(expected_fields, actual_fields)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => {
            :ids => 'unexpected-fields',
            :messages => "Encountered unexpected fields '#{actual_fields}'. Expected: '#{expected_fields}'."
          }
        }
      end

      def wrong_type(field_name, expected_type, actual_type)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => {
            :ids => "wrong-type-#{field_name}",
            :messages => "Expected field type '#{expected_type.is_a?(Proc) ? 'custom matcher' : expected_type}' for field '#{field_name}', but got type '#{actual_type}'."
          }
        }
      end

      def wrong_names(actual_field_names, expected_field_name)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => {
            :ids => "wrong-name-#{expected_field_name}",
            :messages => "Expected field name '#{expected_field_name}', but got #{actual_field_names}."
          }
        }
      end

      def fields_constraint_violation
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => {
            :ids => 'fields-constraint-violation',
            :messages => 'A fields constraint was violated. Check advanced snippet field constraints.'
          }
        }
      end

      def unexpected_error
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => {
            :ids => 'unexpected-error',
            :messages => 'Unexpected error. Check logs for details.'
          }
        }
      end
    end
  end
end
