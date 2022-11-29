#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/validation_status'

shared_examples 'a schema validator' do
  it 'defines validate_against_schema method' do
    expect(described_class.method_defined?(:validate_against_schema)).to eq true
  end
end

shared_examples 'an advanced snippet validator' do
  it 'defines is_snippet_valid method' do
    expect(described_class.method_defined?(:is_snippet_valid)).to eq true
  end
end

shared_examples_for 'filtering is valid' do
  it '' do
    validation_result = described_class.validate_filtering(filtering)

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::VALID)
    expect(validation_result[:errors]).to be_empty
  end
end

shared_examples_for 'filtering is invalid' do
  it '' do
    validation_result = described_class.validate_filtering(filtering)

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
    expect(validation_result[:errors]).to_not be_empty
    expect(validation_result[:errors]).to be_an(Array)
  end
end

shared_examples_for 'simple rules are valid' do
  it '' do
    validation_result = subject.are_rules_valid

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::VALID)
    expect(validation_result[:errors]).to be_empty
  end
end

shared_examples_for 'simple rules are invalid' do
  it '' do
    validation_result = subject.are_rules_valid

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
    expect(validation_result[:errors]).to_not be_empty
    expect(validation_result[:errors]).to be_an(Array)
    expect(validation_result[:errors][0][:ids]).to eq(['simple_rules'])
    expect(validation_result[:errors][0][:messages]).to be_an(Array)
  end
end
