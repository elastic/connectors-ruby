#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job_watcher'

describe ConnectorsAsync::JobWatcher do
  let(:thread_pool_executor) { double }
  let(:job_store) { double }
  let(:jobs) { [] }
  let(:job_watcher) { described_class.new(job_store: job_store) }

  before(:each) do
    allow(Concurrent::ThreadPoolExecutor).to receive(:new).and_return(thread_pool_executor)
    allow(thread_pool_executor).to receive(:post).and_yield # we just threat it in sync mode here
    allow(job_watcher).to receive(:loop).and_yield # we just run the loop once
    allow(job_watcher).to receive(:idle) # and not actually idle

    allow(job_store).to receive(:fetch_all).and_return(jobs)
  end

  context 'when watcher is already watching' do
    before(:each) do
      job_watcher.watch
    end

    it 'raises an error' do
      expect { job_watcher.watch }.to raise_error(ConnectorsAsync::JobWatcher::AlreadyWatchingError)
    end
  end

  context 'when something raises an exception in the watcher loop' do
    before(:each) do
      allow(job_watcher).to receive(:loop).and_yield.and_yield.and_yield # we just run the loop three times

      raised = false
      allow(job_watcher).to receive(:run!) do
        unless raised # first time it's called we raise an error, after we just do nothing
          raised = true
          raise StandardError.new
        end
      end
    end

    it 'logs an error' do
      expect(ConnectorsShared::Logger).to receive(:error)

      job_watcher.watch
    end

    it 'keeps running' do
      expect(job_watcher).to receive(:run!).exactly(3).times

      job_watcher.watch
    end
  end

  context 'when job_store has a couple jobs that are still running' do
    let(:job1) { double }
    let(:job2) { double }
    let(:jobs) { [job1, job2] }

    before(:each) do
      allow(job1).to receive(:safe_to_clean_up?).and_return(false)
      allow(job2).to receive(:safe_to_clean_up?).and_return(false)
    end

    it 'does not attempt to remove them' do
      expect(job_store).to_not receive(:delete_job!)

      job_watcher.watch
    end
  end

  context 'when a finished job can be cleaned up' do
    let(:job_id) { 'this-is-job' }

    let(:job) { double }

    let(:jobs) { [job] }

    before(:each) do
      allow(job).to receive(:safe_to_clean_up?).and_return(true)
      allow(job).to receive(:is_finished?).and_return(true)
      allow(job).to receive(:id).and_return(job_id)
    end

    it 'attempts to remove the job without failing it' do
      expect(job_store).to receive(:delete_job!).with(job_id)
      expect(job).to_not receive(:fail)

      job_watcher.watch
    end
  end

  context 'when a stale job can be cleaned up' do
    let(:job_id) { 'this-is-job' }

    let(:job) { double }

    let(:jobs) { [job] }

    before(:each) do
      allow(job).to receive(:safe_to_clean_up?).and_return(true)
      allow(job).to receive(:is_finished?).and_return(false)
      allow(job).to receive(:id).and_return(job_id)
    end

    it 'attempts to fail and remove the job' do
      expect(job_store).to receive(:delete_job!).with(job_id)
      expect(job).to receive(:fail)

      job_watcher.watch
    end
  end
end
