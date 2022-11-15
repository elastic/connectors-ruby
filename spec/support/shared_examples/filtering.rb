#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

shared_examples 'an advanced snippet validator' do
  it 'defines is_snippet_valid? method' do
    expect(described_class.method_defined?(:is_snippet_valid?)).to eq true
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
  end
end

shared_examples_for 'advanced snippet is valid' do
  it 'is valid' do
    validation_result = subject.is_snippet_valid?

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::VALID)
    expect(validation_result[:errors]).to be_empty
  end
end

shared_examples_for 'advanced snippet is invalid' do |expected_errors|
  it '' do
    validation_result = subject.is_snippet_valid?

    expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
    expect(validation_result[:errors]).to_not be_empty

    expected_errors ||= []

    unless expected_errors.empty?
      # TODO: validate errors
    end
  end
end
