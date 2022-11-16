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
  let(:ops) do
    {
      :equals => Core::Filtering::SimpleRule::Rule::EQUALS,
      :regex => Core::Filtering::SimpleRule::Rule::REGEX,
      :starts_with => Core::Filtering::SimpleRule::Rule::STARTS_WITH,
      :ends_with => Core::Filtering::SimpleRule::Rule::ENDS_WITH,
      :greater_then => Core::Filtering::SimpleRule::Rule::GREATER_THAN,
      :less_then => Core::Filtering::SimpleRule::Rule::LESS_THAN
    }
  end

  let(:field) { 'foo' }
  let(:value) { 'bar' }
  let(:policy) { Core::Filtering::SimpleRule::Policy::INCLUDE }
  let(:operator) { Core::Filtering::SimpleRule::Rule::EQUALS }
  let(:rules) do
    [
      {
        Core::Filtering::SimpleRule::ID => 'test',
        Core::Filtering::SimpleRule::FIELD => field,
        Core::Filtering::SimpleRule::VALUE => value,
        Core::Filtering::SimpleRule::POLICY => policy,
        Core::Filtering::SimpleRule::RULE => operator,
        Core::Filtering::SimpleRule::ORDER => 0
      }
    ]
  end

  subject do
    described_class.new(rules)
  end

  describe '#parse' do
    context 'with one non-default rule' do
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
        context 'starts with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::STARTS_WITH }
          it 'parses rule as starts with' do
            result = subject.parse
            expect(result).to match({ 'foo' => /^bar/ })
          end
        end
        context 'ends with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::ENDS_WITH }
          it 'parses rule as ends with' do
            result = subject.parse
            expect(result).to match({ 'foo' => /bar$/ })
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
        context 'starts with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::STARTS_WITH }
          it 'parses rule as not starts with' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /^bar/ } })
          end
        end
        context 'ends with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::ENDS_WITH }
          it 'parses rule as not ends with' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /bar$/ } })
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
  end

  describe '#validate' do
    let(:expected_rules) { [] }
    shared_examples_for 'keeps valid rules' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
      it 'keeps the rule' do
        expect(subject.rules).to match_array(rules.map { |r| Core::Filtering::SimpleRule.new(r) })
      end
    end

    shared_examples_for 'keeps specific rules' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
      it 'matches expected rules' do
        expect(subject.rules).to match_array(expected_rules.map { |r| Core::Filtering::SimpleRule.new(r) })
      end
    end

    shared_examples_for 'filters invalid rules' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
      it 'drops the rule' do
        expect(subject.rules).to eq([])
      end
    end

    shared_examples_for 'raises_validation_error' do |message|
      it 'raises specific validation error' do
        expect { subject }.to raise_error(Connectors::Base::FilteringRulesValidationError, message)
      end
    end

    context 'with no id on the rule' do
      let(:rules) { [{ field: 'foo', value: 'bar', policy: 'include', rule: ops[:equals] }] }
      it_behaves_like 'raises_validation_error', /id is required/
    end

    context 'with invalid operator' do
      let(:rules) { [{ id: '1', field: 'foo', value: '(', policy: 'include', rule: 'invalid' }] }
      it_behaves_like 'raises_validation_error', /Unknown operator/
    end
    context 'with invalid policy' do
      let(:policy) { 'invalid' }
      it_behaves_like 'raises_validation_error', /Invalid policy/
    end

    context 'with empty string value' do
      let(:value) { '' }
      it_behaves_like 'raises_validation_error', /value is required/
    end

    context 'with empty string field' do
      let(:field) { '' }
      it_behaves_like 'raises_validation_error', /field is required/
    end

    context 'with nil value' do
      let(:value) { nil }
      it_behaves_like 'raises_validation_error', /value is required/
    end

    context 'with nil field' do
      let(:field) { nil }
      it_behaves_like 'raises_validation_error', /field is required/
    end

    context 'with invalid operator' do
      let(:operator) { 'invalid' }
      it 'raises error' do
        expect { subject }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Unknown operator/)
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
        expect { subject }.to raise_error(Connectors::Base::FilteringRulesValidationError, /value is required/)
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
        expect { subject }.to raise_error(Connectors::Base::FilteringRulesValidationError, /field is required/)
      end
    end

    context 'regex' do
      let(:operator) { ops[:regex] }
      context 'with valid regex' do
        let(:value) { '^123$' }
        it_behaves_like 'keeps valid rules'
      end

      context 'with invalid regex' do
        let(:value) { '(' }
        it_behaves_like 'raises_validation_error', /Invalid regex/
      end
    end

    context 'equality' do
      let(:operator) { ops[:equals] }
      context 'with valid equals rule' do
        let(:value) { '123' }
        it_behaves_like 'keeps valid rules'
      end
      context 'with two equals rules' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:equals] },
            { id: '2', field: 'foo', value: '456', policy: 'include', rule: ops[:equals] }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end
    end

    context 'starts_with' do
      let(:operator) { ops[:starts_with] }
      context 'with valid starts_with rule' do
        let(:value) { 'abc' }
        it_behaves_like 'keeps valid rules'
      end

      context 'with include and exclude the same starts_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:starts_with] },
            { id: '2', field: 'foo', value: '123', policy: 'exclude', rule: ops[:starts_with] }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end

      context 'with include and exclude different starts_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:starts_with] },
            { id: '2', field: 'foo', value: '456', policy: 'exclude', rule: ops[:starts_with] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end

      context 'with include and exclude overlapping conflicting starts_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '1234', policy: 'include', rule: ops[:starts_with] },
            { id: '2', field: 'foo', value: '123', policy: 'exclude', rule: ops[:starts_with] }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end

      context 'with include and exclude overlapping non-conflicting starts_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '12', policy: 'include', rule: ops[:starts_with] },
            { id: '2', field: 'foo', value: '123', policy: 'exclude', rule: ops[:starts_with] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end
    end

    context 'ends_with' do
      let(:operator) { ops[:ends_with] }
      context 'with valid ends_with rule' do
        let(:value) { 'abc' }
        it_behaves_like 'keeps valid rules'
      end

      context 'with include and exclude the same ends_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:ends_with] },
            { id: '2', field: 'foo', value: '123', policy: 'exclude', rule: ops[:ends_with] }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end

      context 'with include and exclude different ends_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:ends_with] },
            { id: '2', field: 'foo', value: '456', policy: 'exclude', rule: ops[:ends_with] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end

      context 'with include and exclude overlapping conflicting ends_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:ends_with] },
            { id: '2', field: 'foo', value: '23', policy: 'exclude', rule: ops[:ends_with] }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end

      context 'with include and exclude overlapping non-conflicting ends_with' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: ops[:ends_with] },
            { id: '2', field: 'foo', value: '0123', policy: 'exclude', rule: ops[:ends_with] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end
    end

    context 'ranges' do
      context 'collapses include greater_then' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '3', policy: 'include', rule: ops[:greater_then] },
            { id: '2', field: 'foo', value: '30', policy: 'include', rule: ops[:greater_then] }
          ]
        end
        let(:expected_rules) { [rules[0]] }
        it_behaves_like 'keeps specific rules'
      end
      context 'does not collapse include/exclude greater_then' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '3', policy: 'include', rule: ops[:greater_then] },
            { id: '2', field: 'foo', value: '30', policy: 'exclude', rule: ops[:greater_then] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end
      context 'collapses include less_then' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '3', policy: 'include', rule: ops[:less_then] },
            { id: '2', field: 'foo', value: '30', policy: 'include', rule: ops[:less_then] }
          ]
        end
        let(:expected_rules) { [rules[1]] }
        it_behaves_like 'keeps specific rules'
      end
      context 'does not collapse include/exclude less_then' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '3', policy: 'include', rule: ops[:less_then] },
            { id: '2', field: 'foo', value: '30', policy: 'exclude', rule: ops[:less_then] }
          ]
        end
        it_behaves_like 'keeps valid rules'
      end
    end
  end
end
