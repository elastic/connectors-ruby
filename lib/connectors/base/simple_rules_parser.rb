#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'
require 'core/filtering/simple_rule'

module Connectors
  module Base
    class FilteringRulesValidationError < StandardError; end

    class SimpleRulesParser

      attr_reader :rules

      def initialize(rules)
        sorted = (rules || []).map(&:with_indifferent_access).filter { |r| r[:id] != 'DEFAULT' }.sort_by { |r| r[:order] }
        @rules = validate(sorted)
      end

      def parse
        merge_rules(@rules.map do |rule_hash|
          rule = Core::Filtering::SimpleRule.new(rule_hash)
          unless rule.is_include? || rule.is_exclude?
            raise FilteringRulesValidationError.new("Unknown policy: #{rule[:policy]}")
          end
          parse_rule(rule)
        end)
      end

      def validate(rules)
        return rules if rules.empty?
        rules.each do |rule|
          validate_rule(rule)
        end
        field_acc = {}
        rules.each do |rule|
          if field_acc[rule[:field]].present?
            field_acc[rule[:field]] << rule
          else
            field_acc[rule[:field]] = [rule]
          end
        end
        result = []
        field_acc.each_value do |field_rules|
          result << filter_field_rules(field_rules)
        end
        result.flatten
      end

      private

      def filter_field_rules(field_rules)
        if field_rules.size <= 1
          return field_rules
        end
        # drop contradicting equality rules
        drop_invalid_equality_rules(field_rules)
        # if result.size > 1
        #   result = drop_invalid_range_rules(result)
        # end

        # # check for overlapping ranges
        # ranges = field_rules.filter { |r| r[:rule] == '>' || r[:rule] == '<' }
        # ranges.each_with_index do |r, i|
        #   next if i == ranges.size - 1
        #   next_r = ranges[i + 1]
        #   if r[:value] == next_r[:value]
        #     raise FilteringRulesValidationError.new("Contradicting rules for field: #{field}. Can't have overlapping ranges.")
        #   end
        # end
        #
        # # check for mutually exclusive start_with
        # include_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_include?(r) }.map { |r| r[:value] }
        # exclude_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_exclude?(r) }.map { |r| r[:value] }
        # if include_starts.any? { |s| exclude_starts.any? { |e| s.start_with?(e) } }
        #   raise FilteringRulesValidationError.new("Contradicting [starts_with] rules for field: #{field}. Can't have mutually exclusive [starts_with] rules.")
        # end
        #
        # # check for mutually exclusive end_with
        # include_ends = field_rules.filter { |r| r[:rule] == 'ends_with' && is_include?(r) }.map { |r| r[:value] }
        # exclude_ends = field_rules.filter { |r| r[:rule] == 'ends_with' && is_exclude?(r) }.map { |r| r[:value] }
        # if include_ends.any? { |s| exclude_ends.any? { |e| s.end_with?(e) } }
        #   raise FilteringRulesValidationError.new("Contradicting [ends_with] rules for field: #{field}. Can't have mutually exclusive [ends_with] rules.")
        # end
        # result
      end

      def drop_invalid_equality_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        equality_ids = field_rules.filter { |r| r[:rule] == 'Equals' }.map { |r| r[:id] }
        if equality_ids.size > 1
          # more than one equality rule on the same field, drop all equality rules on the field
          return field_rules.filter { |r| !equality_ids.include?(r[:id]) }
        end
        field_rules
      end

      def drop_invalid_starts_with_rules(field_rules)
        result = field_rules.dup
        # check for mutually exclusive start_with
        include_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_include?(r) }
        exclude_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_exclude?(r) }
        include_starts.each do |include_start|
          invalid_excludes = exclude_starts.filter { |exclude_start| include_start[:value].start_with?(exclude_start[:value]) }
          result = result.delete_if { |r| r[:id] == include_start[:id] || invalid_excludes.any? { |e| e[:id] == r[:id] } }
        end
        result
      end

      def validate_rule(rule)
        op = rule[:rule]&.to_s
        id = rule[:id]&.to_s
        if id.blank?
          raise FilteringRulesValidationError.new('Rule id is required')
        end
        case op
        when 'Equals', '>', '<', 'starts_with', 'ends_with'
          nil
        when 'regex'
          # check validity of regex
          begin
            Regexp.new(rule[:value])
          rescue RegexpError => e
            raise FilteringRulesValidationError.new("Invalid regex rule: #{rule} : (#{e.message})")
          end
        else
          raise FilteringRulesValidationError.new("Unknown operator: #{op}")
        end
      end

      # merge all rules into a filter object or array
      # in a base case, does no transformations
      def merge_rules(rules)
        rules || []
      end

      def parse_rule(_rule)
        raise 'Not implemented'
      end
    end
  end
end
