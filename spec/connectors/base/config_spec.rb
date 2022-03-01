#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/config'

describe Connectors::Base::Config do
  let(:cursors) { { 'cursorKey' => 'cursorValue' } }
  subject { Connectors::Base::Config.new(:cursors => cursors) }

  it 'has cursors' do
    expect(subject.cursors).to eq(cursors)
  end
end
