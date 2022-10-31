#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'

describe Connectors::Base::Connector do
  subject { described_class.send(:new) }

  let(:advanced_config) {
    {
      :filtering => {}
    }
  }

  let(:rules) {
    [{ :some_rule => {} }]
  }

  context '.advanced_config_present?' do
    shared_examples_for 'advanced_config not present' do
      it 'returns false' do
        expect(subject.advanced_config_present?(advanced_config)).to eq(false)
      end
    end

    context 'advanced config is present' do
      it 'returns true' do
        expect(subject.advanced_config_present?(advanced_config)).to eq(true)
      end
    end

    context 'advanced config is nil' do
      let(:advanced_config) {
        nil
      }

      it_behaves_like 'advanced_config not present'
    end

    context 'advanced config is empty' do
      let(:advanced_config) {
        {}
      }

      it_behaves_like 'advanced_config not present'
    end
  end

  context '.rules_present?' do
    shared_examples_for 'rules are not present' do
      it 'returns false' do
        expect(subject.rules_present?(rules)).to eq(false)
      end
    end

    context 'rules are present' do
      it 'returns true' do
        expect(subject.rules_present?(rules)).to eq(true)
      end
    end

    context 'rules are nil' do
      let(:rules) {
        nil
      }

      it_behaves_like 'rules are not present'
    end

    context 'rules are empty' do
      let(:rules) {
        []
      }

      it_behaves_like 'rules are not present'
    end
  end

  context '.filtering_present?' do
    shared_examples_for 'filtering is not present' do
      it 'returns false' do
        expect(subject.filtering_present?(rules, advanced_config)).to eq(false)
      end
    end

    shared_examples_for 'filtering is present' do
      it 'returns true' do
        expect(subject.filtering_present?(rules, advanced_config)).to eq(true)
      end
    end

    context 'rules and advanced_config are present' do
      it_behaves_like 'filtering is present'
    end

    context 'only rules are nil' do
      let(:rules) {
        nil
      }

      it_behaves_like 'filtering is present'
    end

    context 'only rules are empty' do
      let(:rules) {
        []
      }

      it_behaves_like 'filtering is present'
    end

    context 'advanced_config is empty' do
      let(:advanced_config) {
        {}
      }

      it_behaves_like 'filtering is present'
    end

    context 'advanced_config is nil' do
      let(:advanced_config) {
        nil
      }

      it_behaves_like 'filtering is present'
    end

    context 'rules are empty and advanced_config is empty' do
      let(:rules) {
        []
      }

      let(:advanced_config) {
        {}
      }

      it_behaves_like 'filtering is not present'
    end

    context 'rules are nil and advanced_config is nil' do
      let(:rules) {
        nil
      }

      let(:advanced_config) {
        nil
      }

      it_behaves_like 'filtering is not present'
    end
  end
end
