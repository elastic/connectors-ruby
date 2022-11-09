#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering'

module Core
  module Filtering
    class PostProcessEngine
      def initialize(job_description)
        @ordered_rules = ordered_rules(job_description['filtering'])
      end

      def process(document)
        @ordered_rules.each do |rule|
          if rule.match?(document)
            return PostProcessResult.new(document, rule)
          end
        end
        PostProcessResult.new(document, SimpleRule::DEFAULT_RULE)
      end

      def ordered_rules(job_filtering, domain = Core::Filtering::DEFAULT_DOMAIN)
        job_rules = job_filtering.find { |filtering_domain| filtering_domain[Core::Filtering::DOMAIN] == domain }[Core::Filtering::RULES]
        sorted_rules = job_rules.sort_by { |rule| rule['order'] }
        sorted_rules.each_with_object([]) { |rule, output| output << SimpleRule.new(rule) }
      end
    end
  end
end
