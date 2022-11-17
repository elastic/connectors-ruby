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
  class MyConnector
    def initialize(configuration: {}, job_description: {})
      # nothing needed
    end
  end

  before(:each) do
    subject.register('my-connector', MyConnector)
  end

  describe '#connector_class' do
    it 'let us register a connector under a name' do
      connector_class = subject.connector_class('my-connector')
      expect(connector_class == (MyConnector)).to eq(true)
    end
  end

  describe '#registered?' do
    context 'my-connector is registered' do
      it 'should return that sharepoint connector is registered' do
        expect(subject.registered?('my-connector')).to eq(true)
      end

      it 'should return that another-connector is not registered' do
        expect(subject.registered?('another-connector')).to eq(false)
      end
    end
  end

  describe '#connector' do
    context 'my-connector is registered' do
      it 'should return a my-connector instance' do
        connector_instance = subject.connector('my-connector', configuration, job_description)

        expect(connector_instance).to_not be_nil
      end
    end

    context 'another-connector is not registered' do
      it 'should raise an exception, that another-connector is not registered' do
        expect { subject.connector('sharepoint', configuration, job_description) }.to raise_exception
      end
    end
  end

  describe '#registered_connectors' do
    before(:each) do
      subject.register('b-connector', MyConnector)
      subject.register('c-connector', MyConnector)
      subject.register('a-connector', MyConnector)
    end

    it 'returns registered connectors sorted' do
      registered_connectors = subject.registered_connectors

      expect(registered_connectors[0]).to eq('a-connector')
      expect(registered_connectors[1]).to eq('b-connector')
      expect(registered_connectors[2]).to eq('c-connector')
    end
  end
end
