#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/object'
require 'connectors/base/simple_rules_parser'

module Connectors
  module MongoDB
    class MongoRulesParser < Connectors::Base::SimpleRulesParser
      def parse_rule(rule)
        field = rule[:field]
        value = rule[:value]
        unless value.present?
          raise "Value is required for field: #{field}"
        end
        unless field.present?
          raise "Field is required for rule: #{rule}"
        end
        op = rule[:rule]&.to_s
        case op
        when 'Equals'
          parse_equals(rule, field, value)
        when '>'
          parse_greater_than(rule, field, value)
        when '<'
          parse_less_than(rule, field, value)
        when 'regex'
          parse_regex(rule, field, value)
        else
          raise "Unknown operator: #{op}"
        end
      end

      def merge_rules(rules)
        return {} if rules.empty?
        return rules[0] if rules.size == 1
        { '$and' => rules }
      end

      private

      def parse_equals(rule, field, value)
        if is_include?(rule)
          { field => value }
        else
          { field => { '$ne' => value } }
        end
      end

      def parse_greater_than(rule, field, value)
        if is_include?(rule)
          { field => { '$gt' => value } }
        else
          { field => { '$lte' => value } }
        end
      end

      def parse_less_than(rule, field, value)
        if is_include?(rule)
          { field => { '$lt' => value } }
        else
          { field => { '$gte' => value } }
        end
      end

      def parse_regex(rule, field, value)
        if is_include?(rule)
          { field => /#{value}/ }
        else
          { field => { '$not' => /#{value}/ } }
        end
      end
    end
  end
end
