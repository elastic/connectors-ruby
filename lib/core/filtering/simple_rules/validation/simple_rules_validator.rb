# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

module Core
  module Filtering
    module SimpleRules
      module Validation
        SIMPLE_RULES_ID = 'simple_rules'

        class SimpleRulesValidator
          def initialize(rules)
            @rules = rules || []
          end

          def are_rules_valid
            raise 'Simple rules validation not implemented'
          end
        end
      end
    end
  end
end
