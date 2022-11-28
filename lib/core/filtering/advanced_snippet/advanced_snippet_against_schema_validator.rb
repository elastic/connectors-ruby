#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'utility/logger'
require 'core/filtering/advanced_snippet/advanced_snippet_validator'
require 'core/filtering/validation_status'
require 'core/filtering/hash_against_schema_validator'

module Core
  module Filtering
    module AdvancedSnippet
      class AdvancedSnippetAgainstSchemaValidator < Core::Filtering::AdvancedSnippet::AdvancedSnippetValidator

        def initialize(advanced_snippet, schema)
          super(advanced_snippet)
          @schema = schema
          @schema_validator = Core::Filtering::SchemaValidator.new(schema: schema, payload: advanced_snippet, error_id: ADVANCED_SNIPPET_ID)
        end

        def is_snippet_valid
          @schema_validator.validate_against_schema
        end

      end
    end
  end
end
