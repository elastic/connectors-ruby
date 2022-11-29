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
        'id' => 'test',
        'field' => field,
        'value' => value,
        'policy' => policy,
        'rule' => operator
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
        context 'equals' do
          it 'parses rule as equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => 'bar' })
          end
        end

        context 'greater than' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
          it 'parses rule as greater' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gt' => 'bar' } })
          end

          context 'with a number string' do
            let(:value) { '10' }
            it 'parses rule as greater' do
              result = subject.parse
              expect(result).to match({ 'foo' => { '$gt' => 10.0 } })
            end
          end
        end

        context 'less than' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::LESS_THAN }
          it 'parses rule as less' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lt' => 'bar' } })
          end

          context 'with a number string' do
            let(:value) { '10' }
            it 'parses rule as less' do
              result = subject.parse
              expect(result).to match({ 'foo' => { '$lt' => 10.0 } })
            end
          end
        end

        context 'regex' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::REGEX }

          it 'parses rule as a regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => /bar/ })
          end
        end

        context 'starts with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::STARTS_WITH }

          it 'parses rule as a starts with regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => /^bar/ })
          end
        end

        context 'ends with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::ENDS_WITH }

          it 'parses rule as an ends with regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => /bar$/ })
          end
        end

        context 'contains' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::CONTAINS }

          it 'parses rule as a contains regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => /.*bar.*/ })
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

        context 'greater than' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lte' => 'bar' } })
          end
        end

        context 'less than' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::LESS_THAN }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gte' => 'bar' } })
          end
        end

        context 'regex' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::REGEX }

          it 'parses rule as a not regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /bar/ } })
          end
        end

        context 'starts with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::STARTS_WITH }

          it 'parses rule as a not starting with regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /^bar/ } })
          end
        end

        context 'ends with' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::ENDS_WITH }

          it 'parses rule as a not ending with regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /bar$/ } })
          end
        end

        context 'contains' do
          let(:operator) { Core::Filtering::SimpleRule::Rule::CONTAINS }

          it 'parses rule as a not containing regex' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /.*bar.*/ } })
          end
        end
      end
    end

    context 'with multiple rules' do
      let(:rules) do
        [
          {
            'id' => 'test1',
            'field' => 'foo',
            'value' => 'bar1',
            'policy' => Core::Filtering::SimpleRule::Policy::INCLUDE,
            'rule' => Core::Filtering::SimpleRule::Rule::EQUALS
          },
          {
            'id' => 'test2',
            'field' => 'foo',
            'value' => 'bar2',
            'policy' => Core::Filtering::SimpleRule::Policy::EXCLUDE,
            'rule' => Core::Filtering::SimpleRule::Rule::GREATER_THAN
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
        expect { subject.parse }.to raise_error(RuntimeError, /Unknown rule/)
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
            'id' => 'test',
            'field' => field,
            'policy' => policy,
            'rule' => operator
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
            'id' => 'test',
            'value' => value,
            'policy' => policy,
            'rule' => operator
          }
        ]
      end
      it 'raises error' do
        expect { subject.parse }.to raise_error(RuntimeError, /field is required/)
      end
    end
  end
end
