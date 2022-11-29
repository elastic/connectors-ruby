#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/simple_rules/validation/simple_rules_validator'
require 'core/filtering/validation_status'

module Core
  module Filtering
    module SimpleRules
      module Validation
        class NoConflictingPoliciesRulesValidator < Core::Filtering::SimpleRules::Validation::SimpleRulesValidator

          def are_rules_valid
            rule_field_value_to_policy = {}

            @rules.each do |simple_rule|
              rule_field_value = simple_rule.slice('rule', 'field', 'value')
              policy = simple_rule['policy']

              return conflicting_rules(rule_field_value) if rule_field_value_to_policy.key?(rule_field_value)

              rule_field_value_to_policy[rule_field_value] = policy
            end

            { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
          end

          private

          def conflicting_rules(rule_type_value)
            {
              :state => Core::Filtering::ValidationStatus::INVALID,
              :errors => [
                :ids => [SIMPLE_RULES_ID],
                :messages => ["Two simple rules with same rule (#{rule_type_value['rule']}), field (#{rule_type_value['field']}), value (#{rule_type_value['value']}) and conflicting policies detected."]
              ]
            }
          end
        end
      end
    end
  end
end
