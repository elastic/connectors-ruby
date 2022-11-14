#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'connectors/mongodb/mongo_rules_parser'

describe Connectors::MongoDB::MongoRulesParser do
  let(:rules) { [] }
  let(:policy) { '' }
  let(:operator) { '' }

  subject { described_class.new(rules) }

  describe '#parse' do
    context 'with one non-default rule' do
      let(:rules) { [{ id: '123', field: 'foo', value: 'bar', policy: policy, rule: operator }] }
      context 'on include rule' do
        let(:policy) { 'include' }
        context 'equals' do
          let(:operator) { 'Equals' }
          it 'parses rule as equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => 'bar' })
          end
        end
        context 'greater' do
          let(:operator) { '>' }
          it 'parses rule as greater' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gt' => 'bar' } })
          end
        end
        context 'less' do
          let(:operator) { '<' }
          it 'parses rule as less' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lt' => 'bar' } })
          end
        end
        context 'starts with' do
          let(:operator) { 'starts_with' }
          it 'parses rule as starts with' do
            result = subject.parse
            expect(result).to match({ 'foo' => /^bar/ })
          end
        end
        context 'ends with' do
          let(:operator) { 'ends_with' }
          it 'parses rule as ends with' do
            result = subject.parse
            expect(result).to match({ 'foo' => /bar$/ })
          end
        end
      end
      context 'on exclude rule' do
        let(:policy) { 'exclude' }
        context 'equals' do
          let(:operator) { 'Equals' }
          it 'parses rule as not equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$ne' => 'bar' } })
          end
        end
        context 'greater' do
          let(:operator) { '>' }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$lte' => 'bar' } })
          end
        end
        context 'less' do
          let(:operator) { '<' }
          it 'parses rule as less or equals' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$gte' => 'bar' } })
          end
        end
        context 'starts with' do
          let(:operator) { 'starts_with' }
          it 'parses rule as not starts with' do
            result = subject.parse
            expect(result).to match({ 'foo' => { '$not' => /^bar/ } })
          end
        end
        context 'ends with' do
          let(:operator) { 'ends_with' }
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
          { id: '123', field: 'foo', value: 'bar1', policy: 'include', rule: 'Equals' },
          { id: '456', field: 'foo', value: 'bar2', policy: 'exclude', rule: '>' }
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
          { id: '123', field: 'foo', value: 'bla', policy: 'include', rule: 'Equals' }
        ]
      end
      it 'parses rules as just non-default' do
        result = subject.parse
        expect(result).to match({ 'foo' => 'bla' })
      end
    end

    context 'with empty rules' do
      it 'parses rules as empty' do
        result = subject.parse
        expect(result).to match({})
      end
    end

    context 'with invalid operator' do
      let(:rules) { [{ field: 'foo', value: 'bar', policy: 'include', rule: 'invalid' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Unknown operator/)
      end
    end

    context 'with invalid policy' do
      let(:rules) { [{ field: 'foo', value: 'bar', policy: 'invalid', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Unknown policy/)
      end
    end

    context 'with empty string value' do
      let(:rules) { [{ field: 'foo', value: '', policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Value is required/)
      end
    end

    context 'with empty string field' do
      let(:rules) { [{ field: '', value: '123', policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Field is required/)
      end
    end

    context 'with nil value' do
      let(:rules) { [{ field: 'foo', value: nil, policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Value is required/)
      end
    end

    context 'with nil field' do
      let(:rules) { [{ field: nil, value: '123', policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Field is required/)
      end
    end

    context 'with non-existent value' do
      let(:rules) { [{ field: 'foo', policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Value is required/)
      end
    end

    context 'with non-existent field' do
      let(:rules) { [{ value: '123', policy: 'include', rule: 'Equals' }] }
      it 'raises error' do
        expect { subject.parse }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Field is required/)
      end
    end
  end

  describe '#validate' do
    subject { described_class.new(rules) }

    shared_examples_for 'keeps a valid rule' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end
      it 'keeps the rule' do
        expect(subject.rules).to match(rules)
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
      let(:rules) { [{ field: 'foo', value: 'bar', policy: 'include', rule: 'Equals' }] }
      it_behaves_like 'raises_validation_error', /Rule id is required/
    end

    context 'with invalid operator' do
      let(:rules) { [{ id: '1', field: 'foo', value: '(', policy: 'include', rule: 'invalid' }] }
      it 'raises an error' do
        expect { subject.validate(rules) }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Unknown operator/)
      end
    end

    context 'regex' do
      context 'with valid regex' do
        let(:rules) { [{ id: '1', field: 'foo', value: '^123$', policy: 'include', rule: 'regex' }] }
        it 'contains valid rule' do
          expect(subject.validate(rules)).to contain_exactly(rules[0])
        end
      end

      context 'with invalid regex' do
        let(:rules) { [{ id: '1', field: 'foo', value: '(', policy: 'include', rule: 'regex' }] }
        it 'raises an error' do
          expect { subject.validate(rules) }.to raise_error(Connectors::Base::FilteringRulesValidationError, /Invalid regex/)
        end
      end
    end

    context 'equality' do
      context 'with valid equals rule' do
        let(:rules) { [{ id: '1', field: 'foo', value: '123', policy: 'include', rule: 'Equals' }] }
        it_behaves_like 'keeps a valid rule'
      end
      context 'with two equals rules' do
        let(:rules) do
          [
            { id: '1', field: 'foo', value: '123', policy: 'include', rule: 'Equals' },
            { id: '2', field: 'foo', value: '456', policy: 'include', rule: 'Equals' }
          ]
        end
        it_behaves_like 'filters invalid rules'
      end
    end
  end
end
