#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'utility/logger'

module Core
  module Filtering
    class SchemaValidator

      MAX_RECURSION_DEPTH = 50

      def initialize(schema: {}, payload: {}, error_id: '')
        @schema = schema
        @payload = payload
        @error_id = error_id
      end

      def validate_against_schema(schema = @schema, payload = @payload, recursion_depth = 0)
        # Prevent unintentional/intentional SystemStackErrors/crashes
        return unexpected_error if exceeded_recursion_depth?(recursion_depth)

        return valid_snippet unless schema.present?

        schema_fields = schema[:fields].is_a?(Hash) ? schema.dig(:fields, :values) : schema[:fields]
        snippet_field_names = payload&.keys&.map(&:to_s)
        schema_field_names = schema_fields.map { |field| field[:name] }

        return unexpected_field(schema_field_names, snippet_field_names) if unexpected_field_present?(snippet_field_names, schema_field_names)

        return fields_constraint_violation(schema[:fields]) if fields_constraints_violated?(schema[:fields], payload)

        schema_fields.each do |field|
          name = field[:name]
          type = field[:type]
          optional = field[:optional] || false

          snippet_field_value = payload.nil? ? nil : payload.with_indifferent_access[name]

          next if optional && (snippet_field_value.nil? || !snippet_field_value.present?)

          return required_value_missing(name) if is_required_value_missing?(snippet_field_value)

          type_error_present, error_message = type_error_present?(name, type, snippet_field_value)

          return wrong_type(error_message) if type_error_present

          if field[:fields].present?
            validation_result = validate_against_schema(field, snippet_field_value, recursion_depth + 1)

            return validation_result unless validation_result[:state] == Core::Filtering::ValidationStatus::VALID
          end
        end

        valid_snippet
      end

      def fields_constraints_violated?(fields, payload)
        return false if !fields.present? || !fields.is_a?(Hash)

        constraints = fields[:constraints]
        constraints = constraints.is_a?(Array) ? constraints : [constraints]

        constraints.each do |constraint|
          return true unless constraint.call(payload)
        end

        false
      end

      def type_error_present?(field_name, schema_type, actual_value)
        if schema_type.is_a?(Proc)
          result = schema_type.call(actual_value)

          # could already have a custom error message
          if result.is_a?(Array)
            is_valid, error_msg = result

            return !is_valid, error_msg
          end

          # could only return a single boolean
          return !result, 'Custom type matcher validation failed.'
        end

        error_msg = "Expected field type '#{schema_type}' for field '#{field_name}', but got value '#{actual_value.inspect}' of type '#{actual_value.class}'."
        return true, error_msg unless actual_value.is_a?(schema_type)

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
        return false unless actual_field_names.present?

        difference = actual_field_names - expected_field_names

        # we have field names, which we didn't expect
        !difference.empty?
      end

      def is_required_value_missing?(snippet_field_value)
        !snippet_field_value.present?
      end

      def valid_snippet
        {
          :state => Core::Filtering::ValidationStatus::VALID,
          :errors => []
        }
      end

      def required_value_missing(field)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => [
            {
              :ids => [@error_id],
              :messages => ["Required value missing for field '#{field}'."]
            }
          ]
        }
      end

      def unexpected_field(expected_fields, actual_fields)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => [
            {
              :ids => [@error_id],
              :messages => ["Encountered unexpected fields '#{actual_fields}'. Expected: '#{expected_fields}'."]
            }
          ]
        }
      end

      def wrong_type(error_message)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => [
            {
              :ids => [@error_id],
              :messages => [error_message]
            }
          ]
        }
      end

      def fields_constraint_violation(fields)
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => [
            {
              :ids => [@error_id],
              :messages => ["A fields constraint was violated for fields: '#{fields[:values].map { |v| v[:name] }}'."]
            }
          ]
        }
      end

      def unexpected_error
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => [
            {
              :ids => [@error_id],
              :messages => ['Unexpected error. Check logs for details.']
            }
          ]
        }
      end

    end
  end
end
