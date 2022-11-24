#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/simple_rules/validation/single_rule_against_schema_validator'
require 'core/filtering/simple_rules/simple_rule'

describe Core::Filtering::SimpleRules::Validation::SingleRuleAgainstSchemaValidator do
  let(:field) { 'foo' }
  let(:value) { 'bar' }
  let(:order) { 1 }
  let(:policy) { Core::Filtering::SimpleRule::Policy::INCLUDE }
  let(:rule) { Core::Filtering::SimpleRule::Rule::EQUALS }

  let(:simple_rules) do
    [
      {
        'id' => 'test',
        'field' => field,
        'value' => value,
        'policy' => policy,
        'rule' => rule,
        'order' => order
      }
    ]
  end

  subject { described_class.new(simple_rules) }

  describe '#are_rules_valid?' do
    context 'when one valid rule is present' do
      it_behaves_like 'simple rules are valid'
    end

    context 'when field is empty' do
      context 'field is nil' do
        let(:field) {
          nil
        }

        it_behaves_like 'simple rules are invalid'
      end

      context 'field is empty string' do
        let(:field) {
          ''
        }

        it_behaves_like 'simple rules are invalid'
      end
    end

    context 'when value is empty' do
      context 'value is nil' do
        let(:value) {
          nil
        }

        it_behaves_like 'simple rules are invalid'
      end

      context 'value is empty string' do
        let(:value) {
          ''
        }

        it_behaves_like 'simple rules are invalid'
      end
    end

    context 'when policy is empty' do
      context 'policy is nil' do
        let(:policy) {
          nil
        }

        it_behaves_like 'simple rules are invalid'
      end

      context 'policy is empty string' do
        let(:policy) {
          ''
        }

        it_behaves_like 'simple rules are invalid'
      end
    end

    context 'when rule is empty' do
      context 'rule is nil' do
        let(:rule) {
          nil
        }

        it_behaves_like 'simple rules are invalid'
      end

      context 'rule is empty string' do
        let(:rule) {
          ''
        }

        it_behaves_like 'simple rules are invalid'
      end
    end

    context 'when regex rule uses match anything' do
      let(:rule) {
        Core::Filtering::SimpleRule::Rule::REGEX
      }

      context 'when regex has parentheses' do
        let(:value) {
          '(.*)'
        }

        it_behaves_like 'simple rules are invalid'
      end

      context 'when regex does not have parentheses' do
        let(:value) {
          '.*'
        }

        it_behaves_like 'simple rules are invalid'
      end
    end
  end
end
