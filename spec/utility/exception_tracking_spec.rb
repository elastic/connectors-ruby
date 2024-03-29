# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'spec_helper'
require 'utility/exception_tracking'

RSpec.describe Utility::ExceptionTracking do
  let(:message) { 'this is a test message' }
  let(:exception) { StandardError.new(message) }

  describe '.log_exception' do
    it 'can log an exception' do
      expect { described_class.log_exception(exception) }.to output(/#{message}/).to_stdout_from_any_process
    end
  end
end
