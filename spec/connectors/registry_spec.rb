#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/registry'

describe Connectors::Factory do
  subject { described_class.new }

  let(:configuration) {
    {}
  }

  let(:job_description) {
    {}
  }

  let(:registered_connector) {
    'my-connector'
  }

  let(:unregistered_connector) {
    'another-connector'
  }

  class MyConnector
    def initialize(configuration: {}, job_description: {}); end
  end

  before(:each) do
    subject.register(registered_connector, MyConnector)
  end

  describe '#connector_class' do
    context 'when called against previously registered service type' do
      it 'returns registered class' do
        expect(subject.connector_class(registered_connector)).to eq MyConnector
      end
    end
  end

  describe '#registered?' do
    context 'when called against previously registered service type' do
      it 'should return that my-connector is registered' do
        expect(subject.registered?(registered_connector)).to be_truthy
      end
    end

    context 'when called against non-registered service type' do
      it 'should return that non-registered service type is not registered' do
        expect(subject.registered?(unregistered_connector)).to be_falsey
      end
    end
  end

  describe '#connector' do
    context 'when called against previously registered service type' do
      it 'should return the corresponding connector instance' do
        connector_instance = subject.connector(registered_connector, configuration, job_description)

        expect(connector_instance).to be_a(MyConnector)
      end
    end

    context 'when called against non-registered service type' do
      it 'should raise an exception, that non-registered connector is not registered' do
        expect { subject.connector(unregistered_connector, configuration, job_description) }.to raise_exception
      end
    end
  end

  describe '#registered_connectors' do
    let(:registered_connectors) {
      %w[a-connector b-connector c-connector]
    }

    before(:each) do
      registered_connectors.each { |connector| subject.register(connector, MyConnector) }
    end

    it 'returns registered connectors' do
      expect(subject.registered_connectors).to include('a-connector', 'b-connector', 'c-connector')
    end
  end
end
