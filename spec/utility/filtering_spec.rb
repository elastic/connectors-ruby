#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/filtering'

RSpec.describe Utility::Filtering do
  describe '#get_filter' do
    let(:filtering) {
      []
    }

    shared_examples_for 'filtering is empty' do
      it 'returns an empty filter' do
        expect(described_class.extract_filter(filtering)).to be_empty
      end
    end

    shared_examples_for 'filtering is present' do |expected_filter|
      it 'returns filter' do
        expect(described_class.extract_filter(filtering)).to eq(expected_filter)
      end
    end

    context 'filtering is nil' do
      let(:filtering) {
        nil
      }

      it_behaves_like 'filtering is empty'
    end

    context 'filtering is an empty array' do
      let(:filtering) {
        []
      }

      it_behaves_like 'filtering is empty'
    end

    context 'filtering is an empty hash' do
      let(:filtering) {
        {}
      }

      it_behaves_like 'filtering is empty'
    end

    context 'filtering is a hash' do
      let(:filtering) {
        {
          :rules => [],
          :advanced_snippet => {}
        }
      }

      it_behaves_like 'filtering is present', { :rules => [], :advanced_snippet => {} }
    end

    context 'filtering is a one element array' do
      let(:filtering) {
        [
          {
            :rules => [],
            :advanced_snippet => {}
          }
        ]
      }

      it_behaves_like 'filtering is present', { :rules => [], :advanced_snippet => {} }
    end
  end
end
