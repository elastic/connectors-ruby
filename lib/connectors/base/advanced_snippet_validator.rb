#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

module Connectors
  module Base
    class AdvancedSnippetValidator

      def initialize(advanced_snippet)
        @advanced_snippet = advanced_snippet || {}
      end

      def is_snippet_valid?
        raise 'Advanced Snippet validation not implemented'
      end

    end
  end
end
