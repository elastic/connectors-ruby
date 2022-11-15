#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'core/filtering/validation_status'
require 'utility'
require 'faker'

module Connectors
  module Example
    module WithErrors
      class Connector < Connectors::Base::Connector
        def self.service_type
          'example-with-errors'
        end

        def self.display_name
          'Example Connector that produces transient errors'
        end

        # Field 'Foo' won't have a default value. Field 'Bar' will have the default value 'Value'.
        def self.configurable_fields
          {
            'chance_to_raise' => {
              'label' => 'Chance to raise an error when extracting a document (0..100)',
              'value' => 1
            },
            'generated_document_count' => {
              'label' => 'Number of documents to generate',
              'value' => 10000
            }
          }
        end

        def initialize(configuration: {}, job_description: {})
          super

          @chance_to_raise = configuration.dig('chance_to_raise', 'value').to_i
          @generated_document_count = configuration.dig('generated_document_count', 'value').to_i

          raise 'Invalid chance to raise: should be between 0 and 100' if @chance_to_raise < 0 || @chance_to_raise > 100

          Faker::Config.random = Random.new(1337) # we want to have a seed to consistently generate same text over and over
        end

        def do_health_check
        end

        def self.validate_filtering(filtering = {})
          { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
        end

        def yield_documents
          @generated_document_count.times.map do |i|
            raise 'could not extract document' if rand(1..100) > (100 - @chance_to_raise)

            document = { :id => i, :name => Faker::Name.name, :text => Faker::Lorem.sentence }

            yield document
          end
        end
      end
    end
  end
end
