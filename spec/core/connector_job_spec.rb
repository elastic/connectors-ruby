#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core'

describe Core::ConnectorJob do
  subject do
    described_class.new({})
  end

  describe '.fetch_by_id' do
    let(:job_id) { '123' }
    let(:es_response) do
      {
          :found => found
      }
    end
    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:get_job).and_return(es_response)
    end

    context 'when the job does not exist' do
      let(:found) { false }

      it 'returns nil' do
        expect(described_class.fetch_by_id(job_id)).to be_nil
      end
    end

    context 'when the job exists' do
      let(:found) { true }

      it 'returns a job entity' do
        expect(described_class.fetch_by_id(job_id)).to be_kind_of(described_class)
      end
    end
  end

  describe '.pending_jobs' do
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

  # TODO: #done! example should be made as a shared example and tested by #done!, #cancel! and #error!, with only status and error set differently in each example.
  describe '#done!' do
    let(:status) { Connectors::SyncStatus::COMPLETED }
    let(:error) { nil }
    let(:id) { 'id' }
    let(:index_name) { 'index_name' }
    let(:ingestion_stats) { nil }
    let(:connector_metadata) { nil }
    let(:total_document_count) { 100 }

    before(:each) do
      allow(subject).to receive(:id).and_return(id)
      allow(subject).to receive(:index_name).and_return(index_name)
      allow(Core::ElasticConnectorActions).to receive(:document_count).and_return(total_document_count)
      allow(Core::ElasticConnectorActions).to receive(:update_job_fields)
    end

    it 'updates the job as completed' do
      expect(Core::ElasticConnectorActions).to receive(:update_job_fields).with(
        id,
        hash_including(
          :last_seen => anything,
          :completed_at => anything,
          :status => status,
          :error => error,
          :total_document_count => total_document_count
        )
      )
      subject.done!(ingestion_stats, connector_metadata)
    end

    context 'with ingestion stats' do
      let(:ingestion_stats) do
        {
          :indexed_document_count => 1,
          :indexed_document_volume => 13,
          :deleted_document_count => 0
        }
      end

      it 'updates ingestion stats' do
        expect(Core::ElasticConnectorActions).to receive(:update_job_fields).with(
          id, hash_including(ingestion_stats)
        )
        subject.done!(ingestion_stats, connector_metadata)
      end
    end

    context 'with connector metadata' do
      let(:connector_metadata) do
        {
          :foo => 'bar'
        }
      end

      it 'updates connector metadata' do
        expect(Core::ElasticConnectorActions).to receive(:update_job_fields).with(
          id, hash_including(:metadata => connector_metadata)
        )
        subject.done!(ingestion_stats, connector_metadata)
      end
    end
  end

  # The only additional test for #cancel! is that it updates canceled_at
  describe '#cancel!' do
    let(:status) { Connectors::SyncStatus::CANCELED }
    let(:error) { nil }
    let(:id) { 'id' }
    let(:index_name) { 'index_name' }
    let(:ingestion_stats) { nil }
    let(:connector_metadata) { nil }
    let(:total_document_count) { 100 }

    before(:each) do
      allow(subject).to receive(:id).and_return(id)
      allow(subject).to receive(:index_name).and_return(index_name)
      allow(Core::ElasticConnectorActions).to receive(:document_count).and_return(total_document_count)
      allow(Core::ElasticConnectorActions).to receive(:update_job_fields)
    end

    it 'updates canceled_at' do
      expect(Core::ElasticConnectorActions).to receive(:update_job_fields).with(
        id, hash_including(:canceled_at => anything)
      )
      subject.cancel!(ingestion_stats, connector_metadata)
    end
  end
end
