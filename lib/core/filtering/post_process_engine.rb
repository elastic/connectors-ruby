#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering'
require 'utility/filtering'

module Core
  module Filtering
    class PostProcessEngine
      attr_reader :rules

      def initialize(job_description)
        @rules = ordered_rules(job_description['filtering'])
      end

      def process(document)
        @rules.each do |rule|
          if rule.match?(document.stringify_keys)
            return PostProcessResult.new(document, rule)
          end
        end
        PostProcessResult.new(document, SimpleRule::DEFAULT_RULE)
      end

      private

      def ordered_rules(job_filtering)
        job_rules = Utility::Filtering.extract_filter(job_filtering)[Core::Filtering::RULES]
        sorted_rules = job_rules.sort_by { |rule| rule['order'] }.reject { |rule| rule['id'] == Core::Filtering::SimpleRule::DEFAULT_RULE_ID }
        sorted_rules.each_with_object([]) { |rule, output| output << SimpleRule.new(rule) }
      end
    end
  end
end
