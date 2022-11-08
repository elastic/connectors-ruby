#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module Filtering
    class PostProcessResult
      attr_reader :document, :matching_rule

      def initialize(document, matching_rule)
        @document = document
        @matching_rule = matching_rule
      end

      def policy
        matching_rule.policy
      end

      def include?
        policy == 'include'
      end

      def exclude?
        policy == 'exclude'
      end
    end
  end
end
