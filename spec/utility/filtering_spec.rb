#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/filtering'

RSpec.describe Utility::Filtering do
  describe '.get_filter' do
    let(:filtering) {
      []
    }

    let(:filter) {
      {}
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

  describe '.rule_pre_processing_active?' do
    shared_examples_for 'rule pre processing is active' do
      it 'returns true' do
        expect(described_class.rule_pre_processing_active?(filter)).to be_truthy
      end
    end

    shared_examples_for 'rule pre processing is inactive' do
      it 'returns true' do
        expect(described_class.rule_pre_processing_active?(filter)).to be_falsey
      end
    end

    context 'when advanced snippet is not present' do
      context 'when advanced snippet nil' do
        let(:filter) {
          {
            'advanced_snippet' => nil
          }
        }

        it_behaves_like 'rule pre processing is active'
      end

      context 'when advanced snippet is empty' do
        let(:filter) {
          {
            'advanced_snippet' => {}
          }
        }

        it_behaves_like 'rule pre processing is active'
      end

      context 'when value inside advanced snippet is not present' do
        context 'when value is nil' do
          let(:filter) {
            {
              'advanced_snippet' => {
                'value' => nil
              }
            }
          }

          it_behaves_like 'rule pre processing is active'
        end

        context 'when value is empty' do
          let(:filter) {
            {
              'advanced_snippet' => {
                'value' => {}
              }
            }
          }

          it_behaves_like 'rule pre processing is active'
        end
      end
    end

    context 'when advanced snippet value is present' do
      let(:filter) {
        {
          'advanced_snippet' => {
            'value' => {
              'aggregate' => [
                'pipeline' => [
                  {
                    '$project' => {}
                  }
                ]
              ]
            }
          }
        }
      }

      it_behaves_like 'rule pre processing is inactive'
    end
  end
end
