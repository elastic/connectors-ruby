#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/mongodb/mongo_advanced_snippet_snake_case_transformer'

describe Connectors::MongoDB::MongoAdvancedSnippetSnakeCaseTransformer do
  let(:filter) {
    {
      'allowDiskUse' => false,
      'nested' => {
        'maxTimeMS' => 10
      },
      'arrayWithHashes' => [
        {
          'shouldChangeToo' => 10
        },
        {
          'shouldChangeToo' => 10
        },
        {
            'nested' => {
              'someKey' => 'value'
            }
        }
      ]
    }
  }

  subject { described_class.new(filter) }

  describe '#transform' do
    context 'when filter contains camel case keys' do
      it 'transforms all keys to snake_case' do
        expect(subject.transform).to eq({
                                          'allow_disk_use' => false,
                                          'nested' => {
                                            'max_time_ms' => 10
                                          },
                                          'array_with_hashes' => [
                                            {
                                              'should_change_too' => 10
                                            },
                                            {
                                              'should_change_too' => 10
                                            },
                                            {
                                              'nested' => {
                                                'some_key' => 'value'
                                              }
                                            }
                                          ]
                                        })
      end
    end
  end
end
