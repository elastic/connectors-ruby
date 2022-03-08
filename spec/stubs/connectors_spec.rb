#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'stubs/connectors'

describe Connectors do
  it 'connector config should work' do
    expect(Connectors.config.fetch('transient_server_error_retry_delay_minutes')).to eq(5)
  end
end
