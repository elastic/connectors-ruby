# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'spec_helper'
require 'connectors_shared/errors'
require 'connectors_shared/logger'
require 'connectors_shared/monitor'

RSpec.describe ConnectorsShared::Monitor do
  class StubConnector
    def log_debug(message)
      ConnectorsShared::Logger.debug(message)
    end
  end

  let(:connector) { StubConnector.new }
  subject { described_class.new(connector: connector) }

  it 'raises after 10 errors in a row' do
    expect do
      11.times do |n|
        subject.note_error(StandardError.new("This is error number #{n}"))
      end
    end.to raise_error(ConnectorsShared::MaxSuccessiveErrorsExceededError)
  end
end
