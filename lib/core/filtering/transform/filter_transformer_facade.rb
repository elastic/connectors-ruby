#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/transform/transformation_target'
require 'core/filtering/transform/filter_transformer'

module Core
  module Filtering
    module Transform
      class FilterTransformerFacade < Core::Filtering::Transform::FilterTransformer

        def initialize(filter = {},
                       filter_transformers = {
                           Core::Filtering::Transform::TransformationTarget::ADVANCED_SNIPPET => [],
                           Core::Filtering::Transform::TransformationTarget::RULES => [],
                         })
          super(filter)

          rule_transformer_classes = filter_transformers[Core::Filtering::Transform::TransformationTarget::RULES]
          snippet_transformer_classes = filter_transformers[Core::Filtering::Transform::TransformationTarget::ADVANCED_SNIPPET]

          @rule_transformers = rule_transformer_classes.is_a?(Array) ? rule_transformer_classes : [rule_transformer_classes]
          @snippet_transformers = snippet_transformer_classes.is_a?(Array) ? snippet_transformer_classes : [snippet_transformer_classes]

          @facade = FilterTransformer.new(filter, execute_rule_and_snippet_transformations)
        end

        def transform
          @facade.transform
        end

        private

        def execute_rule_and_snippet_transformations
          lambda do |filter|
            rules = filter[:rules]
            advanced_snippet = filter[:advanced_snippet]

            {
              :rules => call_transformers(@rule_transformers, rules),
              :advanced_snippet => call_transformers(@snippet_transformers, advanced_snippet)
            }
          end
        end

        def call_transformers(transformer_classes, payload)
          transformer_classes.each do |transformer_class|
            payload = transformer_class.new(payload).transform if transformer_class.present?
          end

          payload
        end
      end
    end
  end
end
