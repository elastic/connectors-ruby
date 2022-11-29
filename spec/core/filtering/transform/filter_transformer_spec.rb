#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/transform/filter_transformer'

describe Core::Filtering::Transform::FilterTransformer do
  let(:filter) {
    {
      'key' => 'value'
    }
  }

  describe '#transform' do
    subject { described_class.new(filter) }

    context 'when transformation is not specified' do
      it 'returns the original filter' do
        expect(subject.transform).to eq(filter)
      end
    end

    context 'when transformation is present' do
      subject {
        described_class.new(filter, lambda { |filter|
                                      filter['key'] = 'transformed value'
                                      filter
                                    })
      }

      it 'applies transformation' do
        expect(subject.transform).to eq({ 'key' => 'transformed value' })
      end
    end
  end
end
