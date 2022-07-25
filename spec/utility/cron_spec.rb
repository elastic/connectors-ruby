# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'spec_helper'
require 'utility/cron'

RSpec.describe Utility::Cron do

  it 'supports various expressions' do
    expect(subject.convert_expression_from_quartz_to_unix("0 15 10 ? * 6#3")).to eq('15 10 ? * 6#3')

  end
end
