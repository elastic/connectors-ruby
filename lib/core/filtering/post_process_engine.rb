#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/post_process_result'
require 'core/filtering/simple_rule'

module Core
  module Filtering
    class PostProcessEngine
      DEFAULT_DOMAIN = 'DEFAULT'

      def initialize(job_description)
        @ordered_rules = ordered_rules(job_description['filtering'])
      end

      def self.process(document)
        @ordered_rules.each do |rule|
          if rule.match?(document)
            return PostProcessResult.new(document, rule)
          end
        end
        PostProcessResult.new(document, SimpleRule::DEFAULT_RULE)
      end

      def ordered_rules(job_filtering, domain = DEFAULT_DOMAIN)
        job_rules = job_filtering.select { |filtering_domain| filtering_domain['domain'] == domain }['rules']
        sorted_rules = job_rules.sort_by { |rule| rule['order'] }
        sorted_rules.each_with_object([]) { |rule, output| output << SimpleRule.new(rule) }
      end
    end
  end
end
