#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core'

describe Core::JobCleanUp do
  describe '.execute' do
    let(:orphaned_jobs) { [] }
    let(:stuck_jobs) { [] }
    let(:job1) { double }
    let(:job2) { double }

    before(:each) do
      allow(Core::ConnectorJob).to receive(:orphaned_jobs).and_return(orphaned_jobs)
      allow(Core::ConnectorJob).to receive(:stuck_jobs).and_return(stuck_jobs)
    end

    it 'should not clean up orphaned jobs' do
      expect(Core::ElasticConnectorActions).to_not receive(:delete_indices)
      expect(Core::ConnectorJob).to_not receive(:cleanup_jobs)

      described_class.execute
    end

    it 'should not mark stuck jobs error' do
      expect_any_instance_of(Core::ConnectorJob).to_not receive(:error!)
      expect(Core::ConnectorJob).to_not receive(:fetch_by_id)
      expect(Core::ConnectorSettings).to_not receive(:fetch_by_id)
      expect_any_instance_of(Core::ConnectorSettings).to_not receive(:update_last_sync!)

      described_class.execute
    end

    context 'with orphaned jobs' do
      let(:index_name) { 'index_name' }
      let(:orphaned_jobs) { [job1, job2] }

      before(:each) do
        allow(job1).to receive(:index_name).and_return(:index_name)
        allow(job2).to receive(:index_name).and_return(:index_name)
        allow(Core::ConnectorJob).to receive(:cleanup_jobs).and_return({})
      end

      it 'should clean up orphaned jobs' do
        expect(Core::ElasticConnectorActions).to receive(:delete_indices)
        expect(Core::ConnectorJob).to receive(:cleanup_jobs)

        described_class.execute
      end
    end

    context 'with stuck jobs' do
      let(:stuck_jobs) { [job1, job2] }
      let(:connector) { double }
      let(:connector_id) { '1' }
      let(:id1) { '1' }
      let(:id2) { '2' }

      before(:each) do
        allow(job1).to receive(:id).and_return(id1)
        allow(job2).to receive(:id).and_return(id2)
        allow(Core::ConnectorJob).to receive(:fetch_by_id).with(id1).and_return(job1)
        allow(Core::ConnectorJob).to receive(:fetch_by_id).with(id2).and_return(job2)
        allow(job1).to receive(:connector_id).and_return(connector_id)
        allow(job2).to receive(:connector_id).and_return(connector_id)
        allow(job1).to receive(:connector).and_return(connector)
        allow(job2).to receive(:connector).and_return(connector)
      end

      it 'should mark stuck jobs error' do
        expect(job1).to receive(:error!)
        expect(job2).to receive(:error!)
        expect(connector).to receive(:update_last_sync!).twice

        described_class.execute
      end
    end
  end
end
