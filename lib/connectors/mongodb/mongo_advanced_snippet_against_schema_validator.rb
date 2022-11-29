#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/advanced_snippet/advanced_snippet_against_schema_validator'
require 'connectors/mongodb/mongo_advanced_snippet_schema'

module Connectors
  module MongoDB
    class MongoAdvancedSnippetAgainstSchemaValidator < Core::Filtering::AdvancedSnippet::AdvancedSnippetAgainstSchemaValidator

      def initialize(advanced_snippet, schema = Connectors::MongoDB::AdvancedSnippet::SCHEMA)
        super
      end

    end
  end
end
