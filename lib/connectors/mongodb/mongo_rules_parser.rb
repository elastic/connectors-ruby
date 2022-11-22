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
      def parse_rule(simple_rule)
        field = simple_rule.field
        value = simple_rule.value

        raise "value is required for field: #{field}" unless value.present?

        raise "field is required for simple rule: #{simple_rule}" unless field.present?

        rule = simple_rule.rule
        case rule
        when Core::Filtering::SimpleRule::Rule::EQUALS
          parse_equals(simple_rule)
        when Core::Filtering::SimpleRule::Rule::GREATER_THAN
          parse_greater_than(simple_rule)
        when Core::Filtering::SimpleRule::Rule::LESS_THAN
          parse_less_than(simple_rule)
        when Core::Filtering::SimpleRule::Rule::REGEX
          parse_regex(simple_rule)
        when Core::Filtering::SimpleRule::Rule::STARTS_WITH
          parse_starts_with(simple_rule)
        when Core::Filtering::SimpleRule::Rule::ENDS_WITH
          parse_ends_with(simple_rule)
        when Core::Filtering::SimpleRule::Rule::CONTAINS
          parse_contains(simple_rule)
        else
          raise "Unknown rule: #{rule}"
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

      def parse_starts_with(rule)
        if rule.is_include?
          { rule.field => /^#{rule.value}/ }
        else
          { rule.field => { '$not' => /^#{rule.value}/ } }
        end
      end

      def parse_ends_with(rule)
        if rule.is_include?
          { rule.field => /#{rule.value}$/ }
        else
          { rule.field => { '$not' => /#{rule.value}$/ } }
        end
      end

      def parse_contains(rule)
        if rule.is_include?
          { rule.field => /.*#{rule.value}.*/ }
        else
          { rule.field => { '$not' => /.*#{rule.value}.*/ } }
        end
      end
    end
  end
end
