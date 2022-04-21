#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/registry'

describe ConnectorsSdk::Base::Factory do
  let(:factory) do
    described_class.new
  end

  it 'let us register a connector under a name' do
    class MyConnector
      def works
        'works'
      end
    end

    factory.register('sharepoint', MyConnector)
    connector_class = factory.connector_class('sharepoint')
    expect(connector_class.new.works).to eq 'works'
  end
end
