#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering'

describe Core::Filtering::PostProcessEngine do
  let(:job_description) do
    {
      Core::Filtering::FILTERING => [
        {
          Core::Filtering::DOMAIN => Core::Filtering::DEFAULT_DOMAIN,
          Core::Filtering::RULES => rules,
          Core::Filtering::ADVANCED_SNIPPET => snippet,
          Core::Filtering::WARNINGS => []
        }
      ]
    }
  end
  let(:rules) { [] }
  let(:snippet) { {} }
  let(:document) { { 'foo' => 'bar' } }
  let(:test_field) { 'foo' }
  let(:test_value) { 'bar' }
  let(:test_rule) do
    {
      Core::Filtering::SimpleRule::ID => 'test',
      Core::Filtering::SimpleRule::FIELD => test_field,
      Core::Filtering::SimpleRule::VALUE => test_value,
      Core::Filtering::SimpleRule::POLICY => Core::Filtering::SimpleRule::Policy::INCLUDE,
      Core::Filtering::SimpleRule::RULE => Core::Filtering::SimpleRule::Rule::EQUALS
    }
  end

  subject { described_class.new(job_description) }

  shared_examples_for 'included' do
    it 'is included' do
      expect(subject.process(document).is_include?).to be
    end
  end

  shared_examples_for 'excluded' do
    it 'is excluded' do
      processed = subject.process(document)
      expect(processed.is_include?).to be_falsey
    end
  end

  context 'empty rules' do
    it_behaves_like 'included'
  end

  context 'simple rule' do
    let(:rules) { [test_rule] }

    context 'no matches' do
      let(:document) { { 'foo' => 'baz' } }
      it_behaves_like 'excluded'
    end

    context 'document with symbol keys' do
      let(:document) { { :foo => 'bar' } }
      it_behaves_like 'included'
    end

    context 'document with nested field values' do
      let(:document) { { 'foo' => { 'bar' => 'baz' } } }
      context 'when the rule is not nested' do
        it_behaves_like 'excluded'
      end
      context 'when the rule has nested field' do
        let(:test_field) { 'foo.bar' }
        let(:test_value) { 'baz' }
        it_behaves_like 'included'
      end
    end

    context 'document with int values' do
      let(:document) { { 'foo' => 123 } }

      it_behaves_like 'excluded'

      context 'when the rule has the same value' do
        let(:test_value) { 123 }
        it_behaves_like 'included'
      end

    end

    context 'document with date values' do

    end
  end

  context 'multiple rules' do

    context 'same field' do

    end

    context 'different field' do

    end

    context 'ordering' do

      context 'default rule in wrong spot' do

      end
    end
  end
end
