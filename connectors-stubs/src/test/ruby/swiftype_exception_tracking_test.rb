#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require_relative '../../main/ruby/swiftype_exception_tracking'

RSpec.describe Swiftype::ExceptionTracking do
  let(:message) { 'this is a test message' }
  let(:exception) { StandardError.new(message) }

  it "can capture messages" do
    expect { Swiftype::ExceptionTracking.capture_message(message) }.to output(/#{message}/).to_stdout_from_any_process
  end

  it "can can log exceptions" do
    expect { Swiftype::ExceptionTracking.log_exception(exception, message) }.to output(/StandardError/).to_stdout_from_any_process
  end
end