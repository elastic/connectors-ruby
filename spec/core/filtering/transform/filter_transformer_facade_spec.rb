#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'core/filtering/transform/filter_transformer_facade'

describe Core::Filtering::Transform::FilterTransformerFacade do
  let(:filter_key_one) { 'key_one' }
  let(:filter_key_two) { 'key_two' }

  let(:original_value_one) { 'value one' }
  let(:transformed_value_one) { 'transformed value one' }

  let(:original_value_two) { 'value two' }
  let(:transformed_value_two) { 'transformed value two' }

  let(:filter) {
    {
      filter_key_one => original_value_one,
      filter_key_two => original_value_two
    }
  }

  let(:transformer_class_one) { double }
  let(:transformer_instance_one) { double }

  let(:transformer_class_two) { double }
  let(:transformer_instance_two) { double }

  let(:transformer_classes) {
    [
      transformer_class_one,
      transformer_class_two
    ]
  }

  let(:transformation_result_one) {
    lambda { |filter|
      filter[filter_key_one] = transformed_value_one
      filter
    }.call(filter)
  }

  let(:transformation_result_two) {
    lambda { |filter|
      filter[filter_key_two] = transformed_value_two
      filter
    }.call(filter)
  }

  let(:no_transformation) { ->(_filter) { filter }.call(filter) }

  subject { described_class.new(filter, transformer_classes) }

  describe '#transform' do
    before do
      allow(transformer_class_one).to receive(:new).and_return(transformer_instance_one)
      allow(transformer_class_two).to receive(:new).and_return(transformer_instance_two)

      allow(transformer_instance_one).to receive(:transform).and_return(no_transformation)
      allow(transformer_instance_two).to receive(:transform).and_return(no_transformation)
    end

    shared_examples_for 'does not transform' do
      it '' do
        expect(subject.transform).to eq(filter)
      end
    end

    shared_examples_for 'transforms entry one' do
      it '' do
        expect(subject.transform).to eq({ filter_key_one => transformed_value_one, filter_key_two => original_value_two })
      end
    end

    context 'when two transformers are present' do
      context 'when both transformers apply a transformation' do
        before do
          allow(transformer_instance_one).to receive(:transform).and_return(transformation_result_one)
          allow(transformer_instance_two).to receive(:transform).and_return(transformation_result_two)
        end

        it 'transforms both entries' do
          expect(subject.transform).to eq({ filter_key_one => transformed_value_one, filter_key_two => transformed_value_two })
        end
      end

      context 'when transformer one applies a transformation' do
        before do
          allow(transformer_instance_one).to receive(:transform).and_return(transformation_result_one)
        end

        it 'transforms entry one' do
          expect(subject.transform).to eq({ filter_key_one => transformed_value_one, filter_key_two => original_value_two })
        end
      end

      context 'when no transformer applies a transformation' do
        it_behaves_like 'does not transform'
      end
    end

    context 'when one transformer is present' do
      let(:transformer_classes) {
        [
          transformer_class_one
        ]
      }

      context 'when the transformer applies a transformation' do
        before do
          allow(transformer_instance_one).to receive(:transform).and_return(transformation_result_one)
        end

        it_behaves_like 'transforms entry one'
      end

      context 'when the the transformer does not apply a transformation' do
        it_behaves_like 'does not transform'
      end
    end
  end
end
