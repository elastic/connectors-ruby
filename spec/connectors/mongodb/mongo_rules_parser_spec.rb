#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'connectors/mongodb/mongo_rules_parser'
require 'core/filtering/simple_rule'

describe Connectors::MongoDB::MongoRulesParser do
  let(:policy) { '' }
  let(:operator) { '' }

  subject { described_class.new(rules) }

  let(:rules) do
    [
      {
        Core::Filtering::SimpleRule::ID => 'test',
        Core::Filtering::SimpleRule::FIELD => field,
        Core::Filtering::SimpleRule::VALUE => value,
        Core::Filtering::SimpleRule::POLICY => policy,
        Core::Filtering::SimpleRule::RULE => operator
      }
    ]
  end
  let(:field) { 'foo' }
  let(:value) { 'bar' }
  let(:policy) { Core::Filtering::SimpleRule::Policy::INCLUDE }
  let(:operator) { Core::Filtering::SimpleRule::Rule::EQUALS }

  describe '#parse' do
    context 'with one rule' do
      context 'on include rule' do
        context Core::Filtering::SimpleRule::Rule::EQUALS do
          it 'parses rule as equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => 'bar' })
          end
        end
        context 'greater' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
          it 'parses rule as greater' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gt' => 'bar' } })
          end
        end
        context 'less' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::LESS_THAN }
          it 'parses rule as less' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lt' => 'bar' } })
          end
        end
      end
      context 'on exclude rule' do
        let(:policy) { Core::Filtering::SimpleRule::Policy::EXCLUDE }
        context Core::Filtering::SimpleRule::Rule::EQUALS do
          it 'parses rule as not equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$ne' => 'bar' } })
          end
        end
        context 'greater' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lte' => 'bar' } })
          end
        end
        context 'less' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::LESS_THAN }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gte' => 'bar' } })
          end
        end
      end
    end

    context 'with multiple rules' do
      let(:rules) do
        [
          {
            Core::Filtering::SimpleRule::ID => 'test1',
            Core::Filtering::SimpleRule::FIELD => 'foo',
            Core::Filtering::SimpleRule::VALUE => 'bar1',
            Core::Filtering::SimpleRule::POLICY => Core::Filtering::SimpleRule::Policy::INCLUDE,
            Core::Filtering::SimpleRule::RULE => Core::Filtering::SimpleRule::Rule::EQUALS
          },
          {
            Core::Filtering::SimpleRule::ID => 'test2',
            Core::Filtering::SimpleRule::FIELD => 'foo',
            Core::Filtering::SimpleRule::VALUE => 'bar2',
            Core::Filtering::SimpleRule::POLICY => Core::Filtering::SimpleRule::Policy::EXCLUDE,
            Core::Filtering::SimpleRule::RULE => Core::Filtering::SimpleRule::Rule::GREATER_THAN
          }
        ]
      end

      it 'parses rules as and' do
        result = subject.parse
        expect(result).to match({ '$and' => [{ 'foo' => 'bar1' }, { 'foo' => { '$lte' => 'bar2' } }] })
      end
    end

    context 'with one default rule' do
      let(:rules) do
        [
          { id: 'DEFAULT', field: 'foo', value: '*.', policy: 'include', rule: 'regex' }
        ]
      end
      it 'parses rules as empty' do
        result = subject.parse
        expect(result).to match({})
      end
    end

    context 'with one default rule and one non-default' do
      let(:rules) do
        [
          { id: 'DEFAULT', field: 'foo', value: '*.', policy: 'include', rule: 'regex' },
          { id: '123', field: 'foo', value: 'bla', policy: 'include', rule: 'equals' }
        ]
      end
      it 'parses rules as just non-default' do
        result = subject.parse
        expect(result).to match({ 'foo' => 'bla' })
      end
    end

    context 'with empty rules' do
      let(:rules) { [] }
      it 'parses rules as empty' do
        result = subject.parse
        expect(result).to match({})
      end
    end

    context 'with invalid operator' do
      let(:operator) { 'invalid' }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /Unknown operator/)
      end
    end

    context 'with invalid policy' do
      let(:policy) { 'invalid' }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /Unknown policy/)
      end
    end

    context 'with empty string value' do
      let(:value) { '' }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /value is required/)
      end
    end

    context 'with empty string field' do
      let(:field) { '' }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /field is required/)
      end
    end

    context 'with nil value' do
      let(:value) { nil }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /value is required/)
      end
    end

    context 'with nil field' do
      let(:field) { nil }
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /field is required/)
      end
    end

    context 'with non-existent value' do
      let(:rules) do
        [
          {
            Core::Filtering::SimpleRule::ID => 'test',
            Core::Filtering::SimpleRule::FIELD => field,
            Core::Filtering::SimpleRule::POLICY => policy,
            Core::Filtering::SimpleRule::RULE => operator
          }
        ]
      end
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /value is required/)
      end
    end

    context 'with non-existent field' do
      let(:rules) do
        [
          {
            Core::Filtering::SimpleRule::ID => 'test',
            Core::Filtering::SimpleRule::VALUE => value,
            Core::Filtering::SimpleRule::POLICY => policy,
            Core::Filtering::SimpleRule::RULE => operator
          }
        ]
      end
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /field is required/)
      end
    end
  end
end
