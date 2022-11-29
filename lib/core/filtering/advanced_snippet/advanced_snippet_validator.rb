#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'utility/logger'

module Core
  module Filtering
    module AdvancedSnippet
      class AdvancedSnippetValidator

        ADVANCED_SNIPPET_ID = 'advanced_snippet'

        def initialize(advanced_snippet)
          @advanced_snippet = advanced_snippet || {}
        end

        def is_snippet_valid
          raise 'Advanced Snippet validation not implemented'
        end
      end
    end
  end
end
