#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/simple_rules/simple_rule'

module Core
  module Filtering
    module SimpleRules
      module Validation
        DEFAULT_RULE_ID = 'DEFAULT'

        ALLOWED_VALUE_TYPES = ->(rule_value) { rule_value.is_a?(String) || rule_value.is_a?(Integer) || rule_value.is_a?(TrueClass) || rule_value.is_a?(FalseClass) }
        MATCH_ALL_REGEX_NOT_ALLOWED = ->(simple_rule) { simple_rule['id'] == DEFAULT_RULE_ID || !(simple_rule['rule'] == Core::Filtering::SimpleRule::Rule::REGEX && (simple_rule['value'] == '(.*)' || simple_rule['value'] == '.*')) }

        SINGLE_RULE_SCHEMA = {
          :fields => {
            :constraints => [MATCH_ALL_REGEX_NOT_ALLOWED],
            :values => [
              {
                :name => 'id',
                :type => String,
                :optional => false
              },
              {
                :name => 'field',
                :type => String,
                :optional => false
              },
              {
                :name => 'value',
                :type => ALLOWED_VALUE_TYPES,
                :optional => false
              },
              {
                :name => 'policy',
                :type => ->(policy) { Core::Filtering::SimpleRule::Policy::POLICIES.include?(policy) },
                :optional => false
              },
              {
                :name => 'rule',
                :type => ->(rule) { Core::Filtering::SimpleRule::Rule::RULES.include?(rule) },
                :optional => false
              },
              {
                :name => 'order',
                :type => ->(order) { order.is_a?(Integer) && order >= 0 },
              },
              {
                :name => 'updated_at',
                :type => String,
                :optional => true
              },
              {
                :name => 'created_at',
                :type => String,
                :optional => true
              }
            ]
          }
        }
      end
    end
  end
end
