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

  context '#initialize' do
    it 'sets CREATED status' do
      expect(job.status).to eq(ConnectorsShared::JobStatus::CREATED)
    end

    it 'sets the same id that was passed into the constructor' do
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

    context 'when less than up_to documents were stored' do
      let(:stored_document_count) { 15 }
      before(:each) do
        stored_document_count.times do
          job.store({})
        end
      end

      it 'returns all stored docs' do
        expect(job.pop_batch(up_to: 99).size).to eq(stored_document_count)
      end
    end

    context 'when a threading error occurs' do
      let(:queue_mock) { double }
      let(:docs) do
        [
          { :take => 'five' },
          { :art => 'pepper' },
          { :bad => 'not good' },
          { :gonna => 'throw error before this one' }
        ]
      end

      before(:each) do
        allow(Queue).to receive(:new).and_return(queue_mock)

        allow(queue_mock).to receive(:empty?).and_return(false)

        times_called = 0
        allow(queue_mock).to receive(:pop) do
          if times_called == 3
            raise ThreadError
          end
          times_called += 1

          docs[times_called - 1]
        end
      end

      it 'does not throw the ThreadingError' do
        expect { job.pop_batch }.to_not raise_error
      end

      it 'returns the results that got out before the error' do
        expect(job.pop_batch).to eq(docs[0..2])
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

  context '#is_failed?' do
    context 'when job hasn\'t failed before' do
      it 'returns false' do
        expect(job.is_failed?).to eq(false)
      end
    end

    context 'when job failed' do
      before(:each) do
        job.fail(StandardError.new)
      end

      it 'returns true' do
        expect(job.is_failed?).to eq(true)
      end
    end
  end

  context '#update_cursors' do
    it 'updates cursors' do
      new_cursors = { :foxtrot => 'charlie' }

      job.update_cursors(new_cursors)

      expect(job.cursors).to eq(new_cursors)
    end
  end

  context '#has_cursors?' do
    context 'when no cursors were set' do
      it 'returns false' do
        expect(job.has_cursors?).to eq(false)
      end
    end

    context 'when cursors were set' do
      before(:each) do
        job.update_cursors({ :something => 'something' })
      end

      it 'returns true' do
        expect(job.has_cursors?).to eq(true)
      end
    end
  end
end
