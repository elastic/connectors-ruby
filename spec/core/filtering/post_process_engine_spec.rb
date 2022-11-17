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
      'connector' => {
        'filtering' => [
          {
            'domain' => Core::Filtering::DEFAULT_DOMAIN,
            'rules' => rules,
            'advanced_snippet' => snippet,
            'warnings' => []
          }
        ]
      }
    }
  end
  let(:rules) { [] }
  let(:snippet) { {} }
  let(:document) { { 'foo' => 'bar' } }
  let(:test_field) { 'foo' }
  let(:test_value) { 'bar' }
  let(:test_rule_id) { 'test' }
  let(:test_operator) { Core::Filtering::SimpleRule::Rule::EQUALS }
  let(:test_rule) do
    {
      'id' => test_rule_id,
      'field' => test_field,
      'value' => test_value,
      'policy' => Core::Filtering::SimpleRule::Policy::EXCLUDE,
      'rule' => test_operator
    }
  end

  subject { described_class.new(job_description) }

  shared_examples_for 'included' do |matching_rule_id|
    it 'is included' do
      result = subject.process(document)
      expect(result.is_include?).to be
      expect(result.matching_rule.id).to eq(matching_rule_id)
    end
  end

  shared_examples_for 'excluded' do |matching_rule_id|
    it 'is excluded' do
      result = subject.process(document)
      expect(result.is_include?).to be_falsey
      expect(result.matching_rule.id).to eq(matching_rule_id)
    end
  end

  context 'empty rules' do
    it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID
  end

  context 'simple rule' do
    let(:rules) { [test_rule] }

    it_behaves_like 'excluded', 'test'

    context 'no matches' do
      let(:document) { { 'foo' => 'baz' } }

      it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID
    end

    context 'document with symbol keys' do
      let(:document) { { :foo => 'bar' } }

      it_behaves_like 'excluded', 'test'
    end

    context 'document with nested field values' do
      let(:document) { { 'foo' => { 'bar' => 'baz' } } }

      it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID

      context 'when contains rule is used' do
        let(:test_operator) { Core::Filtering::SimpleRule::Rule::CONTAINS }
        it_behaves_like 'excluded', 'test'
      end
    end

    context 'document with int values' do
      let(:document) { { 'foo' => 123 } }

      it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID

      context 'when the rule has the same value' do
        let(:test_value) { 123 }

        it_behaves_like 'excluded', 'test'

        context 'but value is a string' do
          let(:test_value) { '123' }

          it_behaves_like 'excluded', 'test'
        end
      end
    end

    context 'document with date values' do
      context 'rfc3339' do
        let(:document) { { 'foo' => DateTime.parse('2022-11-10T00:00:000Z') } }
        let(:test_value) { '2022-11-10T00:00:000Z' }

        it_behaves_like 'excluded', 'test'

        context 'range operator' do
          let(:test_operator) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
          let(:test_value) { '2022-11-09T00:00:000Z' }

          it_behaves_like 'excluded', 'test'

          context 'other way' do
            let(:test_value) { '2022-11-11T00:00:000Z' }

            it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID
          end
        end
      end

      context 'date only' do
        let(:document) { { 'foo' => DateTime.parse('2022-11-10T00:00:000Z') } }
        let(:test_value) { '2022-11-10' }

        it_behaves_like 'excluded', 'test'
      end

      context 'timestamp only' do
        let(:ts_millis) { DateTime.now.to_time.to_i }
        let(:document) { { 'foo' => Time.at(ts_millis) } }
        let(:test_value) { ts_millis.to_s }

        it_behaves_like 'excluded', 'test'
      end
    end
  end

  context 'multiple rules' do
    let(:document) { { 'foo' => 'bar/baz/qux' } }
    let(:rules) do
      [
        {
          'id' => 'test1',
          'field' => test_field,
          'value' => 'bar/baz',
          'policy' => Core::Filtering::SimpleRule::Policy::INCLUDE,
          'rule' => Core::Filtering::SimpleRule::Rule::STARTS_WITH
        },
        {
          'id' => 'test2',
          'field' => test_field,
          'value' => 'bar',
          'policy' => Core::Filtering::SimpleRule::Policy::EXCLUDE,
          'rule' => Core::Filtering::SimpleRule::Rule::STARTS_WITH
        }
      ]
    end

    context 'same field' do
      context 'included' do
        it_behaves_like 'included', 'test1'
      end

      context 'excluded' do
        let(:document) { { 'foo' => 'bar/qux/baz' } }

        it_behaves_like 'excluded', 'test2'
      end

      context 'no match' do
        let(:document) { { 'foo' => 'qux/bar/baz' } }

        it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID
      end
    end

    context 'default rule in wrong spot' do
      before(:each) do
        rules.unshift(Core::Filtering::SimpleRule::DEFAULT_RULE.to_h)
      end

      it_behaves_like 'included', 'test1'

      it 'does not have the default rule in the ordered rules' do
        expect(subject.rules.map(&:id)).to_not include(Core::Filtering::SimpleRule::DEFAULT_RULE_ID)
      end

      context 'no match' do
        let(:document) { { 'foo' => 'qux/bar/baz' } }

        it_behaves_like 'included', Core::Filtering::SimpleRule::DEFAULT_RULE_ID
      end
    end
  end
end
