#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/transform/filter_transformer'
require 'active_support'

module Connectors
  module MongoDB
    class MongoAdvancedSnippetSnakeCaseTransformer < Core::Filtering::Transform::FilterTransformer

      def initialize(advanced_snippet = {})
        super

        @advanced_snippet = advanced_snippet
        @transformation = ->(snippet) { snake_case_filter(snippet) }
      end

      private

      def snake_case_filter(advanced_snippet, transformed_filter = {})
        advanced_snippet.each do |key, value|
          snake_case_key = key.to_s.underscore

          value = value.is_a?(Hash) ? snake_case_filter(value, {}) : value

          if value.is_a?(Array)
            new_entries = []

            value.each do |entry|
              new_entry = entry.is_a?(Hash) ? snake_case_filter(entry, {}) : entry
              new_entries.push(new_entry)
            end

            value = new_entries
          end

          transformed_filter[snake_case_key] = value
        end

        transformed_filter
      end
    end
  end
end
