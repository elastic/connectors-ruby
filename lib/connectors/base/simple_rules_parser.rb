#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

module Connectors
  module Base
    class SimpleRulesParser
      def initialize(rules)
        @rules = (rules || []).sort_by { |r| r[:order] }
      end

      def parse
        merge_rules(@rules.map do |rule|
          unless is_include?(rule) || is_exclude?(rule)
            raise "Unknown policy: #{rule[:policy]}"
          end
          parse_rule(rule)
        end)
      end

      private

      # merge all rules into a filter object or array
      # in a base case, does no transformations
      def merge_rules(rules)
        rules || []
      end

      def parse_rule(rule)
        raise 'Not implemented'
      end

      def is_include?(rule)
        rule[:policy] == 'include'
      end

      def is_exclude?(rule)
        rule[:policy] == 'exclude'
      end
    end
  end
end
