#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/transform/filter_transformer'

module Core
  module Filtering
    module Transform
      class FilterTransformerFacade < Core::Filtering::Transform::FilterTransformer

        def initialize(filter, transformers = [])
          super(filter)

          @transformer_classes = transformers.is_a?(Array) ? transformers : [transformers]
          @facade = FilterTransformer.new(filter, call_all_transformers)
        end

        def transform
          @facade.transform
        end

        def call_all_transformers
          lambda do |filter|
            @transformer_classes.each do |transformer_class|
              filter = transformer_class.new(filter).transform
            end

            filter
          end
        end
      end
    end
  end
end
