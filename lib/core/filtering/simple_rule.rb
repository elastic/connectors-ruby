#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module Filtering
    class SimpleRule
      POLICY = 'policy'
      FIELD = 'field'
      RULE = 'rule'
      VALUE = 'value'
      ID = 'id'

      DEFAULT_RULE_ID = 'DEFAULT'
      DEFAULT_RULE = SimpleRule.new(
        {
          'policy' => 'include',
          'field' => '_',
          'rule' => 'regex',
          'value' => '.*',
          'id' => SimpleRule::DEFAULT_RULE_ID
        }
      )

      class Policy
        INCLUDE = 'include'
        EXCLUDE = 'exclude'
      end

      class Rule
        REGEX = 'regex'
        EQUALS = 'equals'
        STARTS_WITH = 'starts_with'
        ENDS_WITH = 'ends_with'
        CONTAINS = 'contains'
        LESS_THAN = '<'
        GREATER_THAN = '>'
      end

      attr_reader :policy, :field, :rule, :value, :id

      def initialize(rule_hash)
        @policy = rule_hash.fetch(POLICY)
        @field = rule_hash.fetch(FIELD)
        @rule = rule_hash.fetch(RULE)
        @value = rule_hash.fetch(VALUE)
        @id = rule_hash.fetch(ID)
      end

      def match?(document)
        return true if id == DEFAULT_RULE_ID
        doc_value = document[field]
        case rule
        when Rule::EQUALS
          doc_value == value
        when Rule::STARTS_WITH
          doc_value.starts_with?(value)
        when Rule::ENDS_WITH
          doc_value.ends_with?(value)
        when Rule::CONTAINS
          doc_value.include?(value)
        when Rule::REGEX
          doc_value.match(/#{value}/)
        when Rule::LESS_THAN
          doc_value < value
        when Rule::GREATER_THAN
          doc_value > value
        else
          false
        end
      end
      def is_include?
        policy == Policy::INCLUDE
      end

      def is_exclude?
        policy == Policy::EXCLUDE
      end
    end
  end
end
