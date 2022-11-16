#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'utility/logger'

module Connectors
  module Base
    class AdvancedSnippetValidator

      def initialize(advanced_snippet)
        @advanced_snippet = advanced_snippet || {}
      end

      def is_snippet_valid?
        raise 'Advanced Snippet validation not implemented'
      end

      private

      def log_validation_result(validation_result)
        Utility::Logger.info("Filtering Advanced Configuration validation result: #{validation_result[:state]}")
        if validation_result[:errors].present?
          validation_result[:errors].each do |error|
            Utility::Logger.warn("Validation error for: '#{error[:ids]}': '#{error[:messages]}'")
          end
        end
      end
    end
  end
end
