#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'core/filtering/transform/filter_transformer_facade'

describe Core::Filtering::Transform::FilterTransformerFacade do
  def transform_rule(rules, key, new_value)
    rules.each do |rule|
      rule[key] = new_value if rule.key?(key)
    end

    rules
  end

  def transform_snippet(snippet, key, new_value)
    snippet[key] = new_value

    snippet
  end

  # rules
  let(:rule_one_key) { 'rule one key' }
  let(:rule_two_key) { 'rule two key' }

  let(:original_rule_one_value) { 'rule one value' }
  let(:transformed_rule_one_value) { 'transformed rule one value' }

  let(:original_rule_two_value) { 'rule two value' }
  let(:transformed_rule_two_value) { 'transformed rule two value' }

  let(:rule_transformer_class_one) { double }
  let(:rule_transformer_instance_one) { double }

  let(:rule_transformer_class_two) { double }
  let(:rule_transformer_instance_two) { double }

  let(:rule_transformers) {
    [
      rule_transformer_class_one,
      rule_transformer_class_two
    ]
  }

  let(:rule_transformer_one_transformation_result) {
    transform_rule(rules, rule_one_key, transformed_rule_one_value)
  }

  let(:rule_transformer_two_transformation_result) {
    transform_rule(rules, rule_two_key, transformed_rule_two_value)
  }

  let(:no_rules_transformation_result) { rules }

  let(:rules) {
    [
      {
        rule_one_key => original_rule_one_value,
      },
      {
        rule_two_key => original_rule_two_value
      }
    ]
  }

  # advanced snippet
  let(:snippet_one_key) { 'snippet one key' }
  let(:snippet_two_key) { 'snippet two key' }

  let(:original_snippet_one_value) { 'snippet one value' }
  let(:transformed_snippet_one_value) { 'transformed snippet one value' }

  let(:original_snippet_two_value) { 'snippet two value' }
  let(:transformed_snippet_two_value) { 'transformed snippet two value' }

  let(:snippet_transformer_class_one) { double }
  let(:snippet_transformer_instance_one) { double }

  let(:snippet_transformer_class_two) { double }
  let(:snippet_transformer_instance_two) { double }

  let(:snippet_transformers) {
    [
      snippet_transformer_class_one,
      snippet_transformer_class_two
    ]
  }

  let(:snippet_transformer_one_transformation_result) {
    transform_snippet(advanced_snippet, snippet_one_key, transformed_snippet_one_value)
  }

  let(:snippet_transformer_two_transformation_result) {
    transform_snippet(advanced_snippet, snippet_two_key, transformed_snippet_two_value)
  }

  let(:no_snippet_transformation_result) { advanced_snippet }

  let(:advanced_snippet) {
    {
      snippet_one_key => original_snippet_one_value,
      snippet_two_key => original_snippet_two_value
    }
  }

  let(:filter) {
    {
      :rules => rules,
      :advanced_snippet => advanced_snippet
    }
  }

  subject { described_class.new(filter, rule_transformers, snippet_transformers) }

  describe '#transform' do
    before do
      allow(rule_transformer_class_one).to receive(:new).and_return(rule_transformer_instance_one)
      allow(rule_transformer_class_two).to receive(:new).and_return(rule_transformer_instance_two)

      allow(rule_transformer_instance_one).to receive(:transform).and_return(no_rules_transformation_result)
      allow(rule_transformer_instance_two).to receive(:transform).and_return(no_rules_transformation_result)

      allow(snippet_transformer_class_one).to receive(:new).and_return(snippet_transformer_instance_one)
      allow(snippet_transformer_class_two).to receive(:new).and_return(snippet_transformer_instance_two)

      allow(snippet_transformer_instance_one).to receive(:transform).and_return(no_snippet_transformation_result)
      allow(snippet_transformer_instance_two).to receive(:transform).and_return(no_snippet_transformation_result)
    end

    shared_examples_for 'does not transform' do
      it '' do
        expect(subject.transform).to eq(filter)
      end
    end

    shared_examples_for 'transforms rule entry one' do
      it '' do
        expect(subject.transform).to match(hash_including('rules': [{ rule_one_key => transformed_rule_one_value }, { rule_two_key => original_rule_two_value }]))
      end
    end

    shared_examples_for 'transforms both rules entries' do
      it '' do
        expect(subject.transform).to match(hash_including('rules': [{ rule_one_key => transformed_rule_one_value }, { rule_two_key => transformed_rule_two_value }]))
      end
    end

    shared_examples_for 'transforms snippet entry one' do
      it '' do
        expect(subject.transform).to match(hash_including('advanced_snippet': { snippet_one_key => transformed_snippet_one_value, snippet_two_key => original_snippet_two_value }))
      end
    end

    shared_examples_for 'transforms both snippet entries' do
      it '' do
        expect(subject.transform).to match(hash_including('advanced_snippet': { snippet_one_key => transformed_snippet_one_value, snippet_two_key => transformed_snippet_two_value }))
      end
    end

    context 'when two rule transformers are present' do
      context 'when both rule transformers apply a transformation' do
        before do
          allow(rule_transformer_instance_one).to receive(:transform).and_return(rule_transformer_one_transformation_result)
          allow(rule_transformer_instance_two).to receive(:transform).and_return(rule_transformer_two_transformation_result)
        end

        it_behaves_like 'transforms both rules entries'
      end

      context 'when rule transformer one applies a transformation' do
        before do
          allow(rule_transformer_instance_one).to receive(:transform).and_return(rule_transformer_one_transformation_result)
        end

        it_behaves_like 'transforms rule entry one'
      end

      context 'when no rule transformer applies a transformation' do
        it_behaves_like 'does not transform'
      end
    end

    context 'when one rule transformer is present' do
      let(:rule_transformers) {
        [
          rule_transformer_class_one
        ]
      }

      context 'when the rule transformer applies a transformation' do
        before do
          allow(rule_transformer_instance_one).to receive(:transform).and_return(rule_transformer_one_transformation_result)
        end

        it_behaves_like 'transforms rule entry one'
      end

      context 'when the rule transformer does not apply a transformation' do
        it_behaves_like 'does not transform'
      end
    end

    context 'when no rule transformer is present' do
      let(:rule_transformers) { [] }

      it_behaves_like 'does not transform'
    end

    context 'when two snippet transformers are present' do
      context 'when both snippet transformers apply a transformation' do
        before do
          allow(snippet_transformer_instance_one).to receive(:transform).and_return(snippet_transformer_one_transformation_result)
          allow(snippet_transformer_instance_two).to receive(:transform).and_return(snippet_transformer_two_transformation_result)
        end

        it 'transforms both entries' do
          expect(subject.transform).to match(hash_including('advanced_snippet': { snippet_one_key => transformed_snippet_one_value, snippet_two_key => transformed_snippet_two_value }))
        end
      end

      context 'when snippet transformer one applies a transformation' do
        before do
          allow(snippet_transformer_instance_one).to receive(:transform).and_return(snippet_transformer_one_transformation_result)
        end

        it_behaves_like 'transforms snippet entry one'
      end

      context 'when no snippet transformer applies a transformation' do
        it_behaves_like 'does not transform'
      end
    end

    context 'when one snippet transformer is present' do
      let(:snippet_transformers) {
        [
          snippet_transformer_class_one
        ]
      }

      context 'when the snippet transformer applies a transformation' do
        before do
          allow(snippet_transformer_instance_one).to receive(:transform).and_return(snippet_transformer_one_transformation_result)
        end

        it_behaves_like 'transforms snippet entry one'
      end

      context 'when the snippet transformer does not apply a transformation' do
        it_behaves_like 'does not transform'
      end
    end

    context 'when no snippet transformer is present' do
      let(:snippet_transformers) { [] }

      it_behaves_like 'does not transform'
    end

    context 'two rule transformers and two snippet transformers are present' do
      let(:snippet_transformers) {
        [
          snippet_transformer_class_one,
          snippet_transformer_class_two
        ]
      }

      let(:rule_transformers) {
        [
          rule_transformer_class_one,
          rule_transformer_class_two
        ]
      }

      context 'all transformers apply a transformation' do
        before do
          allow(rule_transformer_instance_one).to receive(:transform).and_return(rule_transformer_one_transformation_result)
          allow(rule_transformer_instance_two).to receive(:transform).and_return(rule_transformer_two_transformation_result)

          allow(snippet_transformer_instance_one).to receive(:transform).and_return(snippet_transformer_one_transformation_result)
          allow(snippet_transformer_instance_two).to receive(:transform).and_return(snippet_transformer_two_transformation_result)
        end

        it_behaves_like 'transforms both rules entries'

        it_behaves_like 'transforms both snippet entries'
      end
    end
  end
end
