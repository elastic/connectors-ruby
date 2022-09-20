#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/registry'

describe Connectors::Registry do
  let(:connector1) { 'connector1' }
  let(:connector2) { 'connector2' }
  let(:connector3) { 'connector3' }
  let(:connector_class1) { double }
  let(:connector_class3) { double }
  let(:connector_instance1) { double }
  let(:connectors_in_yaml) { [connector1, connector2] }
  let(:connector_classes) { [connector_class1, connector_class3] }
  before(:each) do
    allow(App::Config).to receive(:connectors).and_return(connectors_in_yaml)
    allow(Connectors::Base::Connector).to receive(:subclasses).and_return(connector_classes)
    allow(connector_class1).to receive(:service_type).and_return(connector1)
    allow(connector_class3).to receive(:service_type).and_return(connector3)
    allow(connector_class1).to receive(:new).and_return(connector_instance1)
  end

  describe '.registered?' do
    it 'registers connector1' do
      expect(described_class.registered?(connector1)).to be_truthy
    end

    it 'does not register connector2' do
      expect(described_class.registered?(connector2)).to be_falsey
    end

    it 'does not register connector3' do
      expect(described_class.registered?(connector3)).to be_falsey
    end
  end

  describe '.connector_class' do
    it 'returns connector_class1 for connector1' do
      expect(described_class.connector_class(connector1)).to be connector_class1
    end

    it 'returns nil for connector2' do
      expect(described_class.connector_class(connector2)).to be_nil
    end

    it 'returns nil for connector3' do
      expect(described_class.connector_class(connector3)).to be_nil
    end
  end

  describe '.connector' do
    it 'returns connector_instance1 for connector1' do
      expect(described_class.connector(connector1, nil)).to be connector_instance1
    end

    it 'raises error for connector2' do
      expect { described_class.connector(connector2, nil) }.to raise_error
    end

    it 'raises error for connector3' do
      expect { described_class.connector(connector3, nil) }.to raise_error
    end
  end

  describe '.registered_connectors' do
    it 'contains connector1' do
      expect(described_class.registered_connectors).to include(connector1)
    end

    it 'does not contain connector2' do
      expect(described_class.registered_connectors).to_not include(connector2)
    end

    it 'does not contain connector2' do
      expect(described_class.registered_connectors).to_not include(connector3)
    end
  end
end
