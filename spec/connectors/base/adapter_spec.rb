#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true


require 'connectors/base/adapter'
require 'active_support/time_with_zone'

# TODO: do proper mocking
RSpec.describe Connectors::Base::Adapter do
  # XXX This is also stubs in lib/stubs/app_config.rb

  context '.normalize_date' do
    around do |example|
      Time.zone = 'UTC'
      example.run
      Time.zone = nil
    end

    it 'can parse date' do
      described_class.normalize_date('2022-02-22T16:42:44+00:00')
    end
  end
end
