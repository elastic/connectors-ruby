#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'

describe Connectors::Base::Connector do
  subject { described_class.new(configuration: configuration) }

  let(:advanced_config) {
    {
      :some_config => {}
    }
  }

  let(:active_rules) {
    [{ :some_rule => {} }]
  }

  let(:filtering) {
    {
      :advanced_config => advanced_config,
      :rules => active_rules
    }
  }

  let(:configuration) {
    {
      :filtering => {
        :active => filtering
      }
    }
  }

  context '.advanced_config_present?' do
    shared_examples_for 'advanced_config is not present' do
      it 'returns false' do
        expect(subject.advanced_filter_config_present).to eq(false)
      end
    end

    context 'advanced config is present' do
      it 'returns true' do
        expect(subject.advanced_filter_config_present).to eq(true)
      end
    end

    context 'advanced config is nil' do
      let(:advanced_config) {
        nil
      }

      it_behaves_like 'advanced_config is not present'
    end

    context 'advanced config is empty' do
      let(:advanced_config) {
        {}
      }

      it_behaves_like 'advanced_config is not present'
    end
  end

  context '.rules_present?' do
    shared_examples_for 'rules are not present' do
      it 'returns false' do
        expect(subject.active_rules_present?).to eq(false)
      end
    end

    context 'rules are present' do
      it 'returns true' do
        expect(subject.active_rules_present?).to eq(true)
      end
    end

    context 'rules are nil' do
      let(:active_rules) {
        nil
      }

      it_behaves_like 'rules are not present'
    end

    context 'rules are empty' do
      let(:active_rules) {
        []
      }

      it_behaves_like 'rules are not present'
    end
  end

  context '.filtering_present?' do
    shared_examples_for 'filtering is not present' do
      it 'returns false' do
        expect(subject.filtering_present?).to eq(false)
      end
    end

    shared_examples_for 'filtering is present' do
      it 'returns true' do
        expect(subject.filtering_present?).to eq(true)
      end
    end

    context 'rules and advanced_config are present' do
      it_behaves_like 'filtering is present'
    end

    context 'only rules are nil' do
      let(:active_rules) {
        nil
      }

      it_behaves_like 'filtering is present'
    end

    context 'only rules are empty' do
      let(:active_rules) {
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
      let(:active_rules) {
        []
      }

      let(:advanced_config) {
        {}
      }

      it_behaves_like 'filtering is not present'
    end

    context 'rules are nil and advanced_config is nil' do
      let(:active_rules) {
        nil
      }

      let(:advanced_config) {
        nil
      }

      it_behaves_like 'filtering is not present'
    end

    context '.initialize' do
      context 'three rules are present' do
        let(:active_rules) {
          [
          { :name => 'rule one' },
          { :name => 'rule two' },
          { :name => 'rule three' },
        ]
        }

        it 'should extract three rules from job description' do
          extracted_rules = subject.active_rules

          expect(extracted_rules).to_not be_nil
          expect(extracted_rules.size).to eq(3)

          expect(extracted_rules[0][:name]).to eq('rule one')
          expect(extracted_rules[1][:name]).to eq('rule two')
          expect(extracted_rules[2][:name]).to eq('rule three')
        end
      end

      shared_examples_for 'has default rules value' do
        it 'defaults to an empty array' do
          extracted_rules = subject.active_rules

          expect(extracted_rules).to_not be_nil
          expect(extracted_rules.size).to eq(0)
        end
      end

      context 'no rules are present' do
        let(:active_rules) {
          []
        }

        it_behaves_like 'has default rules value'
      end

      context 'rules are nil' do
        let(:active_rules) {
          nil
        }

        it_behaves_like 'has default rules value'
      end

      context 'filter config is present' do
        let(:advanced_config) {
          {
            :field_one => 'field one',
            :field_two => 'field two',
            :field_three => 'field three',
          }
        }

        it 'extracts the filter config' do
          extracted_filter_config = subject.advanced_filter_config

          expect(extracted_filter_config).to_not be_nil
          expect(extracted_filter_config[:field_one]).to eq('field one')
          expect(extracted_filter_config[:field_two]).to eq('field two')
          expect(extracted_filter_config[:field_three]).to eq('field three')
        end
      end

      shared_examples_for 'has default filter config value' do
        it 'defaults to an empty hash' do
          extracted_filter_config = subject.advanced_filter_config

          expect(extracted_filter_config).to_not be_nil
          expect(extracted_filter_config).to eq({})
        end
      end

      context 'filter config is nil' do
        let(:advanced_config) {
          nil
        }

        it_behaves_like 'has default filter config value'
      end

      context 'filter config is empty' do
        let(:advanced_config) {
          {}
        }

        it_behaves_like 'has default filter config value'
      end
    end
  end
end
