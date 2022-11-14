#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'

module Connectors
  module Base
    class FilteringRulesValidationError < StandardError; end

    class SimpleRulesParser
      def initialize(rules)
        sorted = (rules || []).map(&:with_indifferent_access).filter { |r| r[:id] != 'DEFAULT' }.sort_by { |r| r[:order] }
        @rules = validate(sorted)
      end

      def parse
        merge_rules(@rules.map do |rule|
          unless is_include?(rule) || is_exclude?(rule)
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
        field_acc.each_entry do |field, field_rules|
          validate_field_rules(field, field_rules)
        end
        rules
      end

      private

      def validate_field_rules(field, field_rules)
        if field_rules.size <= 1
          return
        end

        # check for contradicting equality rules
        equal_count = field_rules.count { |r| r[:rule] == 'Equals' }
        if equal_count > 1
          raise FilteringRulesValidationError.new("Contradicting rules for field: #{field}. Can't have more than one equality clause.")
        end

        # check for overlapping ranges
        ranges = field_rules.filter { |r| r[:rule] == '>' || r[:rule] == '<' }
        ranges.each_with_index do |r, i|
          next if i == ranges.size - 1
          next_r = ranges[i + 1]
          if r[:value] == next_r[:value]
            raise FilteringRulesValidationError.new("Contradicting rules for field: #{field}. Can't have overlapping ranges.")
          end
        end

        # check for mutually exclusive start_with
        include_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_include?(r) }.map { |r| r[:value] }
        exclude_starts = field_rules.filter { |r| r[:rule] == 'starts_with' && is_exclude?(r) }.map { |r| r[:value] }
        if include_starts.any? { |s| exclude_starts.any? { |e| s.start_with?(e) } }
          raise FilteringRulesValidationError.new("Contradicting [starts_with] rules for field: #{field}. Can't have mutually exclusive [starts_with] rules.")
        end

        # check for mutually exclusive end_with
        include_ends = field_rules.filter { |r| r[:rule] == 'ends_with' && is_include?(r) }.map { |r| r[:value] }
        exclude_ends = field_rules.filter { |r| r[:rule] == 'ends_with' && is_exclude?(r) }.map { |r| r[:value] }
        if include_ends.any? { |s| exclude_ends.any? { |e| s.end_with?(e) } }
          raise FilteringRulesValidationError.new("Contradicting [ends_with] rules for field: #{field}. Can't have mutually exclusive [ends_with] rules.")
        end
      end

      def validate_rule(rule)
        op = rule[:rule]&.to_s
        case op
        when 'Equals', '>', '<', 'starts_with', 'ends_with'
          nil
        when 'regex'
          # check validity of regex
          begin
            Regexp.new(value)
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

      def is_include?(rule)
        rule['policy'] == 'include'
      end

      def is_exclude?(rule)
        rule['policy'] == 'exclude'
      end
    end
  end
end
