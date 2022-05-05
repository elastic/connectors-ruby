#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job'
require 'connectors_shared/job_status'

describe ConnectorsAsync::Job do
  let(:job_id) { 12345 }
  let(:job) { described_class.new(job_id) }

  context 'job was just created' do
    it 'has CREATED status' do
      expect(job.status).to eq(ConnectorsShared::JobStatus::CREATED)
    end

    it 'has the same id that was passed into the constructor' do
      expect(job.id).to eq(job_id)
    end
  end

  context '#update_status' do
    context 'when job hasn\'t finished' do
      it 'allows to update status' do
        new_status = ConnectorsShared::JobStatus::RUNNING

        job.update_status(new_status)

        expect(job.status).to eq(new_status)
      end
    end

    context 'when job has finished' do
      before(:each) do
        job.update_status(ConnectorsShared::JobStatus::FINISHED)
      end

      it 'raises an error' do
        expect { job.update_status(ConnectorsShared::JobStatus::RUNNING) }.to raise_error(ConnectorsAsync::Job::StatusUpdateError)
      end
    end
  end

  context '#store' do
    it 'stores an item that can later be retrieved' do
      doc1 = { apple: 'a day' }
      doc2 = { keeps: 'a doctor away' }

      job.store(doc1)
      job.store(doc2)

      data = job.pop_batch

      expect(data).to include(doc1)
      expect(data).to include(doc2)
    end
  end

  context '#pop_batch' do
    context 'when no documents were stored' do
      it 'returns an empty array' do
        expect(job.pop_batch).to be_empty
      end
    end
  end

  context '#fail' do
    let(:error) { StandardError.new }

    before(:each) do
      job.fail(error)
    end

    it 'changes job status to failed' do
      expect(job.status).to eq(ConnectorsShared::JobStatus::FAILED)
    end

    it 'stores an error' do
      expect(job.error).to eq(error)
    end
  end

  context '#has_error?' do
    context 'when job hasn\'t failed before' do
      it 'returns false' do
        expect(job.has_error?).to eq(false)
      end
    end

    context 'when job failed' do
      before(:each) do
        job.fail(StandardError.new)
      end

      it 'returns true' do
        expect(job.has_error?).to eq(true)
      end
    end
  end
end
