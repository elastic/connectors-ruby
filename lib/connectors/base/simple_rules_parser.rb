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

      include Core::Filtering

      attr_reader :rules

      def initialize(rules)
        begin
          sorted = (rules || []).map { |r| SimpleRule.new(r) }.filter { |r| r.id != 'DEFAULT' }.sort_by(&:order)
        rescue StandardError => e
          raise FilteringRulesValidationError, "Invalid rule: #{e.message}"
        end
        @rules = validate(sorted)
      end

      def parse
        merge_rules(@rules.map do |rule|
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
          if field_acc[rule.field].present?
            field_acc[rule.field] << rule
          else
            field_acc[rule.field] = [rule]
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
        # drop contradicting rules
        result = drop_invalid_equality_rules(field_rules)
        result = drop_invalid_starts_with_rules(result)
        result = drop_invalid_ends_with_rules(result)
        result = collapse_range_rules(result)
        drop_invalid_range_rules(result)
      end

      def drop_invalid_equality_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        equality_ids = field_rules.filter { |r| r.rule == SimpleRule::Rule::EQUALS }.map(&:id)
        if equality_ids.size > 1
          # more than one equality rule on the same field, drop all equality rules on the field
          return field_rules.filter { |r| !equality_ids.include?(r.id) }
        end
        field_rules
      end

      def drop_invalid_starts_with_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        result = field_rules.dup
        # check for exclude and include with the same or overlapping start_with
        include_starts = field_rules.filter { |r| r.rule == SimpleRule::Rule::STARTS_WITH && r.is_include? }
        exclude_starts = field_rules.filter { |r| r.rule == SimpleRule::Rule::STARTS_WITH && r.is_exclude? }
        include_starts.each do |include_start|
          invalid_excludes = exclude_starts.filter { |exclude_start| include_start.value.start_with?(exclude_start.value) }
          if invalid_excludes.present?
            result -= invalid_excludes
            result -= [include_start]
          end
        end
        result
      end

      def drop_invalid_ends_with_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        result = field_rules.dup
        # check for exclude and include with the same or overlapping ends_with
        include_starts = field_rules.filter { |r| r.rule == SimpleRule::Rule::ENDS_WITH && r.is_include? }
        exclude_starts = field_rules.filter { |r| r.rule == SimpleRule::Rule::ENDS_WITH && r.is_exclude? }
        include_starts.each do |include_start|
          invalid_excludes = exclude_starts.filter { |exclude_start| include_start.value.end_with?(exclude_start.value) }
          if invalid_excludes.present?
            result -= invalid_excludes
            result -= [include_start]
          end
        end
        result
      end

      def collapse_range_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        result = field_rules.dup
        greater_ranges = field_rules.filter { |r| r.rule == SimpleRule::Rule::GREATER_THAN }
        greater_ranges.each do |range|
          result -= greater_ranges.filter { |r| r.id != range.id && r.policy == range.policy && r.value >= range.value }
        end
        lesser_ranges = field_rules.filter { |r| r.rule == SimpleRule::Rule::LESS_THAN }
        lesser_ranges.each do |range|
          result -= lesser_ranges.filter { |r| r.id != range.id && r.policy == range.policy && r.value <= range.value }
        end
        result
      end

      def drop_invalid_range_rules(field_rules)
        if (field_rules || []).size <= 1
          return field_rules
        end
        result = field_rules.dup
        greater_ranges = field_rules.filter { |r| r.rule == SimpleRule::Rule::GREATER_THAN }
        greater_ranges.each do |range|
          conflicts = field_rules.filter { |r| r.id != range.id && r.policy == range.policy && r.rule == SimpleRule::Rule::LESS_THAN && r.value <= range.value }
          if conflicts.present?
            result -= conflicts
            result -= [range]
          end
        end
        lesser_ranges = field_rules.filter { |r| r.rule == SimpleRule::Rule::LESS_THAN }
        lesser_ranges.each do |range|
          conflicts = field_rules.filter { |r| r.id != range.id && r.policy == range.policy && r.rule == SimpleRule::Rule::GREATER_THAN && r.value >= range.value }
          if conflicts.present?
            result -= conflicts
            result -= [range]
          end
        end
        result
      end

      def validate_rule(rule)
        op = rule.rule&.to_s
        id = rule.id&.to_s
        raise FilteringRulesValidationError.new('Rule id is required') if id.blank?
        raise FilteringRulesValidationError.new('value is required') if rule.value.blank?
        raise FilteringRulesValidationError.new('field is required') if rule.field.blank?
        case op
        when SimpleRule::Rule::EQUALS,
          SimpleRule::Rule::GREATER_THAN,
          SimpleRule::Rule::LESS_THAN,
          SimpleRule::Rule::STARTS_WITH,
          SimpleRule::Rule::ENDS_WITH,
          SimpleRule::Rule::CONTAINS
          nil
        when SimpleRule::Rule::REGEX
          # check validity of regex
          begin
            Regexp.new(rule.value)
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
