#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/connector'

describe App::Connector do
  it 'should raise error for invalid service type' do
    allow(App::Config).to receive(:[]).with('service_type').and_return('foobar')
    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(nil)
    expect { described_class.start! }.to raise_error('foobar is not a supported connector')
  end

  it 'should start only once' do
    allow(described_class).to receive(:pre_flight_check)
    allow(described_class).to receive(:start_polling_jobs)
    described_class.start!
    expect(described_class.running?).to be_truthy
    expect { described_class.start! }.to raise_error('The connector app is already running!')
  end
end
