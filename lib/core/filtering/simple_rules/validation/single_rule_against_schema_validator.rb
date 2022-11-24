#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/simple_rules/validation/simple_rules_validator'
require 'core/filtering/hash_against_schema_validator'
require 'core/filtering/simple_rules/validation/simple_rules_schema'

module Core
  module Filtering
    module SimpleRules
      module Validation
        class SingleRuleAgainstSchemaValidator < Core::Filtering::SimpleRules::Validation::SimpleRulesValidator

          def initialize(rules, schema = Core::Filtering::SimpleRules::Validation::SINGLE_RULE_SCHEMA)
            super(rules)
            @schema = schema
            @schema_validator = SchemaValidator.new(error_id: SIMPLE_RULES_ID)
          end

          def are_rules_valid?
            @rules.each do |rule|
              validation_result = @schema_validator.validate_against_schema(@schema, rule)
              return validation_result unless validation_result[:state] == Core::Filtering::ValidationStatus::VALID
            end

            { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
          end

        end
      end
    end
  end
end
