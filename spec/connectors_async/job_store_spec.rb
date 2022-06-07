#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job_store'

describe ConnectorsAsync::JobStore do
  let(:job_store) { described_class.new }

  context '#create_job' do
    it 'returns a job with generated id' do
      job = job_store.create_job

      expect(job.id).to_not be_empty
    end

    it 'returns a job with unique id' do
      job1 = job_store.create_job
      job2 = job_store.create_job

      expect(job1.id).to_not eq(job2.id)
    end
  end

  context '#fetch_job' do
    context 'when id of non-existing job is passed' do
      it 'raises an error' do
        expect { job_store.fetch_job('lalala') }.to raise_error(ConnectorsAsync::JobStore::JobNotFoundError)
      end
    end

    context 'when a job was created before' do
      let(:job) { job_store.create_job }

      it 'returns a job' do
        expect(job_store.fetch_job(job.id)).to eq(job)
      end
    end
  end

  context '#delete_job!' do
    context 'when id of non-existing job is passed' do
      it 'raises an error' do
        expect { job_store.delete_job!('lalala') }.to raise_error(ConnectorsAsync::JobStore::JobNotFoundError)
      end
    end

    context 'when id of existing job is passed' do
      let(:job) { job_store.create_job }

      it 'removes this job' do
        job_store.delete_job!(job.id)

        expect { job_store.fetch_job(job.id) }.to raise_error(ConnectorsAsync::JobStore::JobNotFoundError)
      end
    end
  end

  context '#fetch_all' do
    let!(:job1) { job_store.create_job }
    let!(:job2) { job_store.create_job }
    let!(:job3) { job_store.create_job }

    it 'returns all stored jobs' do
      jobs = job_store.fetch_all

      expect(jobs).to include(job1, job2, job3)
    end
  end
end
