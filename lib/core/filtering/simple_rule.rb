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
        when 'equals'
          doc_value == value
        when 'starts_with'
          doc_value.starts_with?(value)
        when 'ends_with'
          doc_value.ends_with?(value)
        when 'contains'
          doc_value.include?(value)
        when 'regex'
          doc_value.match(/#{value}/)
        when '<'
          doc_value < value
        when '>'
          doc_value > value
        else
          false
        end
      end
    end
  end
end

