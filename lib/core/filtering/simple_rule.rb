#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Core
  module Filtering
    class SimpleRule
      POLICY = 'policy'
      FIELD = 'field'
      RULE = 'rule'
      VALUE = 'value'
      ID = 'id'

      DEFAULT_RULE_ID = 'DEFAULT'

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
        @rule_hash = rule_hash
      rescue KeyError => e
        raise "#{e.key} is required"
      end

      def self.from_args(id, policy, field, rule, value)
        SimpleRule.new(
          {
            ID => id,
            POLICY => policy,
            FIELD => field,
            RULE => rule,
            VALUE => value
          }
        )
      end

      DEFAULT_RULE = SimpleRule.new(
        'policy' => 'include',
        'field' => '_',
        'rule' => 'regex',
        'value' => '.*',
        'id' => SimpleRule::DEFAULT_RULE_ID
      )

      def match?(document)
        return true if id == DEFAULT_RULE_ID
        doc_value = document[field]
        return false if doc_value.nil?
        coerced_value = coerce(doc_value)
        case rule
        when Rule::EQUALS
          case coerced_value
          when Integer
            doc_value == coerced_value
          when DateTime, Time
            doc_value.to_s == coerced_value.to_s
          else
            doc_value.to_s == coerced_value
          end
        when Rule::STARTS_WITH
          doc_value.to_s.start_with?(value)
        when Rule::ENDS_WITH
          doc_value.to_s.end_with?(value)
        when Rule::CONTAINS
          doc_value.to_s.include?(value)
        when Rule::REGEX
          doc_value.to_s.match(/#{value}/)
        when Rule::LESS_THAN
          doc_value < coerced_value
        when Rule::GREATER_THAN
          doc_value > coerced_value
        else
          false
        end
      end

      def coerce(doc_value)
        case doc_value
        when String
          value.to_s
        when Integer
          value.to_i
        when DateTime, Time
          to_date(value)
        when TrueClass, FalseClass # Ruby doesn't have a Boolean type, TIL
          to_bool(value).to_s
        else
          value.to_s
        end
      rescue StandardError => e
        Utility::Logger.debug("Failed to coerce value '#{value}' (#{value.class}) based on document value '#{doc_value}' (#{doc_value.class}) due to error: #{e.class}: #{e.message}")
        value.to_s
      end

      def is_include?
        policy == Policy::INCLUDE
      end

      def is_exclude?
        policy == Policy::EXCLUDE
      end

      def to_h
        @rule_hash
      end

      private

      def to_bool(str)
        return true if str == true || str =~ (/^(true|t|yes|y|on|1)$/i)
        return false if str == false || str.blank? || str =~ (/^(false|f|no|n|off|0)$/i)
        raise ArgumentError.new("invalid value for Boolean: \"#{str}\"")
      end

      def to_date(str)
        DateTime.parse(str)
      rescue ArgumentError
        Time.at(str.to_i) # try with it as an int string of millis
      end
    end
  end
end
