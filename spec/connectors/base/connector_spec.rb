#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'core/filtering/filter_validator'
require 'spec_helper'

describe Connectors::Base::Connector do
  subject { described_class.new(configuration: connector_configuration, job_description: job_description) }

  let(:advanced_snippet) {
    {
      :find => {
        :filter => {
          :$text => {
            :$search => 'garden',
            :$caseSensitive => false
          }
        },
        :options => {
          :skip => 10,
          :limit => 1000
        }
      }
    }
  }

  let(:rules) {
    [
      {
        :id => '90owilfksdoifuw',
        :policy => 'exclude',
        :field => 'url',
        :rule => 'regex',
        :value => '.*/sample/.*\.pdf',
        :order => 0,
        :created_at => '2022-10-10T00:00:00Z',
        :updated_at => '2022-10-10T00:00:00Z'
      }
    ]
  }

  let(:filtering) {
    {
      :advanced_snippet => advanced_snippet,
      :rules => rules
    }
  }

  let(:filter_validator) { double }

  let(:job_description) { double }
  let(:job_configuration) { { :job_key => 'value' } }
  let(:connector_configuration) { { :connector_key => 'value' } }

  before(:each) do
    allow(job_description).to receive(:dup).and_return(job_description)
    allow(job_description).to receive(:configuration).and_return(job_configuration)
    allow(job_description).to receive(:filtering).and_return(filtering)
    allow(Core::Filtering::FilterValidator).to receive(:new).and_return(filter_validator)
  end

  describe '.initialize' do
    it 'uses job configuration' do
      expect(subject.instance_variable_get('@configuration')).to eq(job_configuration)
    end

    context 'when job configuration is not provided' do
      let(:job_configuration) { nil }

      it 'uses connector configuration' do
        expect(subject.instance_variable_get('@configuration')).to eq(connector_configuration)
      end
    end
  end

  describe '#advanced_filter_config' do
    shared_examples_for 'advanced_filter_config is not present' do
      it 'returns empty object' do
        expect(subject.advanced_filter_config).to be_empty
      end
    end

    context 'advanced filter config is present' do
      it 'returns advanced filter config' do
        expect(subject.advanced_filter_config).to eq(advanced_snippet)
      end
    end

    context 'advanced filter config is nil' do
      let(:advanced_snippet) {
        nil
      }

      it_behaves_like 'advanced_filter_config is not present'
    end

    context 'advanced filter config is empty' do
      let(:advanced_snippet) {
        {}
      }

      it_behaves_like 'advanced_filter_config is not present'
    end
  end

  describe '#rules' do
    shared_examples_for 'rules are not present' do
      it 'returns empty array' do
        expect(subject.rules).to be_empty
      end
    end

    context 'rules are present' do
      it 'returns true' do
        expect(subject.rules).to eq(rules)
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

  describe '.rules' do
    let(:rules) {
      [
        {
          :id => '90owilfksdoifuw',
          :policy => 'exclude',
          :field => 'url',
          :rule => 'regex',
          :value => '.*/sample/.*\.pdf',
          :order => 0,
          :created_at => '2022-10-10T00:00:00Z',
          :updated_at => '2022-10-10T00:00:00Z'
        },
        {
          :id => '09wuekwisdfjslk',
          :policy => 'include',
          :field => 'id',
          :rule => 'regex',
          :value => '.*',
          :order => 1,
          :created_at => '2022-10-10T00:00:00Z',
          :updated_at => '2022-10-10T00:00:00Z'
        }
      ]
    }

    context 'two rules are present' do
      it 'should extract three rules from job description' do
        extracted_rules = subject.rules

        expect(extracted_rules).to_not be_nil
        expect(extracted_rules.size).to eq(2)

        expect(extracted_rules[0]).to eq(rules[0])
        expect(extracted_rules[1]).to eq(rules[1])
      end
    end

    shared_examples_for 'has default rules value' do
      it 'defaults to an empty array' do
        extracted_rules = subject.rules

        expect(extracted_rules).to_not be_nil
        expect(extracted_rules.size).to eq(0)
      end
    end

    context 'no rules are present' do
      let(:rules) {
        []
      }

      it_behaves_like 'has default rules value'
    end

    context 'rules are nil' do
      let(:rules) {
        nil
      }

      it_behaves_like 'has default rules value'
    end

    context 'advanced filter config is present' do
      it 'extracts the advanced filter config' do
        advanced_filter_config = subject.advanced_filter_config

        expect(advanced_filter_config).to eq(advanced_snippet)
      end
    end

    shared_examples_for 'has default filter config value' do
      it 'defaults to an empty hash' do
        advanced_filter_config = subject.advanced_filter_config

        expect(advanced_filter_config).to_not be_nil
        expect(advanced_filter_config).to eq({})
      end
    end

    context 'filter config is nil' do
      let(:advanced_snippet) {
        nil
      }

      it_behaves_like 'has default filter config value'
    end

    context 'filter config is empty' do
      let(:advanced_snippet) {
        {}
      }

      it_behaves_like 'has default filter config value'
    end
  end

  describe '.validate_filtering' do
    context 'when filtering is valid' do
      before do
        allow(filter_validator).to receive(:is_filter_valid).with(filtering).and_return({ :state => Core::Filtering::ValidationStatus::VALID, :errors => [] })
      end

      it_behaves_like 'filtering is valid'
    end

    context 'when filtering is invalid' do
      before do
        allow(filter_validator).to receive(:is_filter_valid).with(filtering).and_return({ :state => Core::Filtering::ValidationStatus::INVALID, :errors => [{ :ids => ['error-id'], :messages => ['error-message'] }] })
      end

      it_behaves_like 'filtering is invalid'
    end
  end
end
