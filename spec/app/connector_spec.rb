#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/connector'

describe App::Connector do
  it 'should start only once' do
    allow(described_class).to receive(:start_polling_jobs)
    described_class.start!
    expect(described_class.running?).to be_truthy
    expect { described_class.start! }.to raise_error('The connector app is already running!')
  end
end
