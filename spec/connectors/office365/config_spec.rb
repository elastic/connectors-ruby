#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/office365/config'

describe Connectors::Office365::Config do
  let(:cursors) { { 'foo' => 'bar' } }
  let(:drive_ids) { described_class::ALL_DRIVE_IDS }
  subject { described_class.new(:cursors => cursors, :drive_ids => drive_ids) }

  it 'serializes' do
    hsh = subject.to_h
    expect(hsh).to eq({:cursors => cursors, :drive_ids => drive_ids, :index_permissions => false})
  end
end
