#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/object'
require 'connectors/base/simple_rules_parser'
require 'core/filtering/simple_rule'

module Connectors
  module MongoDB
    class MongoRulesParser < Connectors::Base::SimpleRulesParser
      def parse_rule(rule)
        field = rule.field
        value = rule.value
        # unless value.present?
        #   raise Connectors::Base::FilteringRulesValidationError.new("Value is required for field: #{field}")
        # end
        # unless field.present?
        #   raise Connectors::Base::FilteringRulesValidationError.new("Field is required for rule: #{rule}")
        # end
        op = rule.rule
        case op
        when SimpleRule::Rule::EQUALS
          parse_equals(rule)
        when SimpleRule::Rule::GREATER_THAN
          parse_greater_than(rule)
        when SimpleRule::Rule::LESS_THAN
          parse_less_than(rule)
        when SimpleRule::Rule::REGEX
          parse_regex(rule)
        when SimpleRule::Rule::STARTS_WITH
          parse_starts_with(rule, field, value)
        when SimpleRule::Rule::ENDS_WITH
          parse_ends_with(rule, field, value)
        else
          raise Connectors::Base::FilteringRulesValidationError.new("Unknown operator: #{op}")
        end
      end

      def merge_rules(rules)
        return {} if rules.empty?
        return rules[0] if rules.size == 1
        { '$and' => rules }
      end

      private

      def parse_equals(rule)
        if rule.is_include?
          { rule.field => rule.value }
        else
          { rule.field => { '$ne' => rule.value } }
        end
      end

      def parse_greater_than(rule)
        if rule.is_include?
          { rule.field => { '$gt' => rule.value } }
        else
          { rule.field => { '$lte' => rule.value } }
        end
      end

      def parse_less_than(rule)
        if rule.is_include?
          { rule.field => { '$lt' => rule.value } }
        else
          { rule.field => { '$gte' => rule.value } }
        end
      end

      def parse_regex(rule)
        if rule.is_include?
          { rule.field => /#{rule.value}/ }
        else
          { rule.field => { '$not' => /#{rule.value}/ } }
        end
      end

      def parse_starts_with(rule, field, value)
        if rule.is_include?
          { field => /^#{value}/ }
        else
          { field => { '$not' => /^#{value}/ } }
        end
      end

      def parse_ends_with(rule, field, value)
        if rule.is_include?
          { field => /#{value}$/ }
        else
          { field => { '$not' => /#{value}$/ } }
        end
      end
    end
  end
end
