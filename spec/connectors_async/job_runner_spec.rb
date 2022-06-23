#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job_runner'
require 'connectors_async/job_watcher'
require 'connectors/base/adapter'

describe ConnectorsAsync::JobRunner do
  let(:job_runner) { described_class.new(max_threads: 4) }

  context '#start_job' do
    let(:connector) { double }
    let(:access_token) { 'salad is OK' }
    let(:params) do
      {
        :modified_since => nil,
        :access_token => access_token,
        :cursors => {}
      }
    end
    let(:secret_storage) { double }
    let(:job) { double }
    let(:job_watcher) { double }
    let(:thread_executor_mock) { double }
    let(:extraction_time) { 0 }
    let(:connector_class) { double }
    let(:cursors_after_extraction) { { :canyon => 'crayons' } }
    let(:content_source_id) { 'asdfg-125913qasg9125' }

    before(:each) do
      allow(job).to receive(:id).and_return(1)
      allow(job).to receive(:update_status)
      allow(job).to receive(:update_cursors)
      allow(job).to receive(:should_wait?).and_return(false)
      allow(job).to receive(:store)

      allow(job_watcher).to receive(:watch)

      allow(connector).to receive(:extract) do |&block|
        sleep(extraction_time) if extraction_time > 0
        block.call
      end.and_return(cursors_after_extraction)

      allow(secret_storage).to receive(:fetch_secret).with(content_source_id).and_return(access_token)

      allow(connector_class).to receive(:new).and_return(connector)
      allow(ConnectorsAsync::JobWatcher).to receive(:new).and_return(job_watcher)
    end

    context 'extractor takes a long time to complete' do
      let(:extraction_time) { 1 }

      it 'returns immediately' do
        start_time = Time.now

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          secret_storage: secret_storage,
          params: params
        )

        end_time = Time.now

        expect(end_time - start_time).to be < 0.01
      end
    end

    context 'when extractor completes immediately' do
      let(:extraction_time) { 0 }

      it 'updates the job status throughout the run' do
        expect(job).to receive(:update_status).with(Utility::JobStatus::RUNNING)
        expect(job).to receive(:update_status).with(Utility::JobStatus::FINISHED)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          secret_storage: secret_storage,
          params: params
        )

        idle_a_bit
      end

      it 'updates the cursors with cursors received from extractor' do
        expect(job).to receive(:update_cursors).with(cursors_after_extraction)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          secret_storage: secret_storage,
          params: params
        )

        idle_a_bit
      end

      context 'when extractor returns results' do
        let(:docs) do
          [
            { :golden => 'cobra' },
            { :polar => 'bear' },
            { :stick => 'shift' }
          ]
        end

        before(:each) do
          expectation = allow(connector).to receive(:extract)
          docs.each do |doc|
            expectation = expectation.and_yield(doc)
          end
        end

        it 'stores docs in the job' do
          docs.each do |doc|
            expect(job).to receive(:store).with(doc)
          end

          job_runner.start_job(
            job: job,
            connector_class: connector_class,
            secret_storage: secret_storage,
            params: params
          )

          idle_a_bit
        end
      end

      context 'when extractor raises an error' do
        let(:error_message) { 'lol here we are' }
        let(:error) { StandardError.new(error_message) }

        before(:each) do
          allow(connector).to receive(:extract).and_raise(error)
        end

        it 'fails job' do
          expect(job).to receive(:fail).with(error)

          job_runner.start_job(
            job: job,
            connector_class: connector_class,
            secret_storage: secret_storage,
            params: params
          )

          idle_a_bit
        end
      end
    end

    # A little context here - the method normalize_date uses Time.zome.parse
    # that requires Time.zone to be initialized. When the actual thread starts,
    # we need to initialize it, therefore this test is here.
    # If normalize_date stops using Time.zone
    context 'when extractor calls Connectors::Base::Adapter.normalize_data' do
      before(:each) do
        allow(connector).to receive(:extract) do
          Connectors::Base::Adapter.normalize_date('2014-12-04T11:02:37Z')
        end
      end

      it 'does not raise an error' do
        expect(job).to_not receive(:fail)
        expect(job).to receive(:update_status).with(Utility::JobStatus::FINISHED)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          secret_storage: secret_storage,
          params: params
        )

        idle_a_bit
      end
    end

    context 'when job indicates that no results were picked up for a bit' do
      before(:each) do
        allow(job).to receive(:should_wait?).and_return(true, true, false)
        allow(job_runner).to receive(:sleep) { ; }
      end

      it 'throttles the run until the job no longer indicates it should be throttled' do
        expect(job_runner).to receive(:idle)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          secret_storage: secret_storage,
          params: params
        )

        idle_a_bit
      end

      context 'when job idled for too long' do
        before(:each) do
          allow(job).to receive(:should_wait?).and_return(true)
        end

        it 'fails a job' do
          expect(job).to receive(:fail).with(instance_of(ConnectorsAsync::JobRunner::JobStuckError))

          job_runner.start_job(
            job: job,
            connector_class: connector_class,
            secret_storage: secret_storage,
            params: params
          )

          idle_a_bit
        end
      end
    end
  end

  def idle_a_bit
    # not perfect, can be changed to poll the job status actually if starts to fail
    sleep 0.1
  end
end
