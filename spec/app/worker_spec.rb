#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/worker'

describe App::Worker do
  it 'should raise error for invalid service type' do
    allow(App::Config).to receive(:[]).with(:service_type).and_return('foobar')
    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(nil)
    expect { described_class.start! }.to raise_error('foobar is not a supported connector')
  end
end
