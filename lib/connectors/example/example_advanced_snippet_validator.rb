#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/advanced_snippet/advanced_snippet_validator'
require 'core/filtering/validation_status'

module Connectors
  module Example
    class ExampleAdvancedSnippetValidator < Core::Filtering::AdvancedSnippet::AdvancedSnippetValidator

      def is_snippet_valid?
        # TODO: real filtering validation will follow later
        errors = [
          {
            :ids => ['missing-implementation'],
            :messages => ['Filtering is not implemented yet for the example connector']
          }
        ]

        validation_result = if @advanced_snippet.present? && !@advanced_snippet.empty?
                              { :state => Core::Filtering::ValidationStatus::INVALID, :errors => errors }
                            else
                              { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
                            end
        log_validation_result(validation_result)
        validation_result
      end

    end
  end
end
