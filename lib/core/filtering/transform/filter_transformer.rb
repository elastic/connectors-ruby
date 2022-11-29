#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module Filtering
    module Transform
      class FilterTransformer

        def initialize(filter = {}, transformation = (->(_filter) { filter }))
          @filter = filter
          @transformation = transformation
        end

        def transform
          @transformation.call(@filter)
        end

      end
    end
  end
end
