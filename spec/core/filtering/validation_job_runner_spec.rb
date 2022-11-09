#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/validation_status'
require 'core/filtering/validation_job_runner'
require 'core/elastic_connector_actions'
require 'core/connector_settings'
require 'connectors/registry'

describe Core::Filtering::ValidationJobRunner do
  subject { described_class.new(connector_settings) }

  let(:connector_id) { 123 }
  let(:connector_class) { double }
  let(:connector_settings) { double }

  let(:service_type) { 'foo' }
  let(:filtering) { {} }

  let(:validation_state) {
    Core::Filtering::ValidationStatus::EDITED
  }

  let(:validation_errors) {
    []
  }

  let(:validation_result) {
    {
      :state => validation_state,
      :errors => validation_errors
    }
  }

  before(:each) do
    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)

    allow(Core::ElasticConnectorActions).to receive(:update_filtering_validation)
    allow(Core::ElasticConnectorActions).to receive(:update_connector_status)

    allow(connector_settings).to receive(:id).and_return(connector_id)
    allow(connector_settings).to receive(:filtering).and_return(filtering)
    allow(connector_settings).to receive(:service_type).and_return(service_type)

    allow(connector_class).to receive(:service_type).and_return(service_type)
    allow(connector_class).to receive(:validate_filtering).with(filtering).and_return(validation_result)
  end

  shared_examples_for 'updates the filtering validation' do |connector_id, expected_validation_result|
    it "sets filtering validation with validation result #{expected_validation_result}" do
      expect(Core::ElasticConnectorActions).to receive(:update_filtering_validation).with(connector_id, { 'DEFAULT' => validation_result })
      subject.execute

      expect(subject.instance_variable_get(:@validation_finished)).to eq(true)
    end
  end

  context '.execute' do
    context 'when validation state is \'valid\' and no errors are present' do
      let(:validation_state) {
        Core::Filtering::ValidationStatus::VALID
      }

      let(:errors) {
        []
      }

      it_behaves_like 'updates the filtering validation', 123, { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
    end

    context 'when validation state is \'invalid\' and errors are present' do
      let(:validation_state) {
        Core::Filtering::ValidationStatus::INVALID
      }

      let(:validation_errors) {
        [
          'Error 1',
          'Error 2',
          'Error 3'
        ]
      }

      it_behaves_like 'updates the filtering validation', 123, { :state => Core::Filtering::ValidationStatus::INVALID, :errors => ['Error 1',
                                                                                                                                   'Error 2',
                                                                                                                                   'Error 3'] }
    end

    context 'when an error is thrown during validation' do
      before(:each) do
        allow(connector_class).to receive(:validate_filtering).with(filtering).and_raise(StandardError.new('Error occurred during validation'))
      end

      it 'sets a filtering error and logs the exception' do
        expect(Core::ElasticConnectorActions).to receive(:update_filtering_validation) { |actual_connector_id, validation_result|
          expect(actual_connector_id).to eq(connector_id)

          validation_result = validation_result['DEFAULT']

          expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
          expect(validation_result[:errors]).to_not be_empty
        }

        expect(Utility::ExceptionTracking).to receive(:log_exception)

        subject.execute

        expect(subject.instance_variable_get(:@validation_finished)).to eq(false)
      end
    end

    context 'when validation thread did not finish execution' do
      before(:each) do
        allow(connector_class).to receive(:validate_filtering).with(filtering).and_raise(Exception)
      end

      it 'sets an error, that the validation thread was killed' do
        # Check for exception thrown on purpose, so that the test is not marked as failed for the wrong reason
        expect { subject.execute }.to raise_exception

        expect(subject.instance_variable_get(:@validation_finished)).to eq(false)
        expect(subject.instance_variable_get(:@status)[:error]).to eq('Validation thread did not finish execution. Check connector logs for more details.')
      end
    end
  end
end
