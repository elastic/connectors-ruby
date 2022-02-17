#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require_relative '../../main/ruby/connectors_exception_tracking'

RSpec.describe ConnectorsExceptionTracking do
  let(:message) { 'this is a test message' }
  let(:exception) { StandardError.new(message) }

  it "can log an exception" do
    expect { ConnectorsExceptionTracking.log_exception(exception) }.to output(/#{message}/).to_stdout_from_any_process
  end
end