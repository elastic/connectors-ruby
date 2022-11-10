#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core'

describe Core::ConnectorJob do
  describe '#pending_jobs' do
    let(:jobs) do
      [
         { '_id' => '123', '_source' => { 'something' => 'something', 'status' => Connectors::SyncStatus::PENDING } }.with_indifferent_access,
         { '_id' => '456', '_source' => { 'something' => 'something', 'status' => Connectors::SyncStatus::SUSPENDED } }.with_indifferent_access
      ]
    end

    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:search_jobs).and_return({
        'hits' => {
          'hits' => jobs,
          'total' => {
            'value' => jobs.size
          }
        }
      })
    end

    it 'returns job entities' do
      results = described_class.pending_jobs

      actual_job_ids = results.map(&:id)
      expected_job_ids = jobs.map { |c| c['_id'] }

      expect(expected_job_ids).to eq(actual_job_ids)
    end
  end
end
