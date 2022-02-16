#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require_relative '../../main/ruby/connectors_errors'
require_relative '../../main/ruby/connectors_logger'
require_relative '../../main/ruby/connectors_monitor'


RSpec.describe ConnectorsMonitor do

  class StubConnector
    def log_debug(message)
      ConnectorsLogger.debug(message)
    end
  end

  let(:connector) { StubConnector.new }
  subject { ConnectorsMonitor.new(:connector => connector)}

  it "raises after 10 errors in a row" do
    expect do
      11.times do |n|
        subject.note_error(StandardError.new("This is error number #{n}"))
      end
    end.to raise_error(MaxSuccessiveErrorsExceededError)
  end


end