#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/simple_rules/simple_rule'
require 'core/filtering/simple_rules/validation/no_conflicting_policies_rules_validator'

describe Core::Filtering::SimpleRules::Validation::NoConflictingPoliciesRulesValidator do
  let(:field) { 'foo' }
  let(:value) { 'bar' }
  let(:rule) { Core::Filtering::SimpleRule::Rule::EQUALS }

  let(:simple_rule_including) {
    {
      'id' => 'test',
      'field' => field,
      'value' => value,
      'policy' => Core::Filtering::SimpleRule::Policy::INCLUDE,
      'rule' => rule
    }
  }

  let(:simple_rule_excluding) {
    {
      'id' => 'test',
      'field' => field,
      'value' => value,
      'policy' => Core::Filtering::SimpleRule::Policy::EXCLUDE,
      'rule' => rule
    }
  }

  let(:simple_rules) {
    []
  }

  subject { described_class.new(simple_rules) }

  describe '#are_rules_valid' do
    context 'when one simple rule uses include policy and another simple rule uses exclude policy for the same fields' do
      context 'when include rule comes before the exclude rule' do
        let(:simple_rules) do
          [
            simple_rule_including,
            simple_rule_excluding
          ]
        end

        it_behaves_like 'simple rules are invalid'
      end

      context 'when exclude rule comes before the include rule' do
        let(:simple_rules) do
          [
            simple_rule_excluding,
            simple_rule_including
          ]
        end

        it_behaves_like 'simple rules are invalid'
      end
    end

    context 'when simple rules do not conflict' do
      let(:simple_rules) do
        [
          {
            'id' => 'test',
            'field' => field,
            'value' => value,
            'policy' => Core::Filtering::SimpleRule::Policy::INCLUDE,
            'rule' => rule
          },
          {
            'id' => 'test',
            'field' => 'another-field',
            'value' => 'another-value',
            'policy' => Core::Filtering::SimpleRule::Policy::EXCLUDE,
            'rule' => Core::Filtering::SimpleRule::Rule::CONTAINS
          }
        ]
      end

      it_behaves_like 'simple rules are valid'
    end
  end
end
