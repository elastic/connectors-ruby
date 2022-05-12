#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job_runner'

describe ConnectorsAsync::JobRunner do
  let(:job_runner) { described_class.new(max_threads: 4) }

  context '#start_job' do
    let(:connector) { double }
    let(:modified_since) { nil }
    let(:access_token) { 'salad is OK' }
    let(:job) { double }
    let(:thread_executor_mock) { double }
    let(:extraction_time) { 0 }
    let(:connector_class) { double }
    let(:cursors) { {} }
    let(:cursors_after_extraction) { { :canyon => 'crayons' } }

    before(:each) do
      allow(job).to receive(:id).and_return(1)
      allow(job).to receive(:update_status)
      allow(job).to receive(:update_cursors)

      allow(connector).to receive(:extract) do
        sleep(extraction_time) if extraction_time > 0
      end.and_return(cursors_after_extraction)

      allow(connector_class).to receive(:new).and_return(connector)
    end

    context 'extractor takes a long time to complete' do
      let(:extraction_time) { 1 }

      it 'returns immediately' do
        start_time = Time.now

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          modified_since: modified_since,
          access_token: access_token,
          cursors: cursors
        )

        end_time = Time.now

        expect(end_time - start_time).to be < 0.01
      end
    end

    context 'when extractor completes immediately' do
      let(:extraction_time) { 0 }

      it 'updates the job status throughout the run' do
        expect(job).to receive(:update_status).with(ConnectorsShared::JobStatus::RUNNING)
        expect(job).to receive(:update_status).with(ConnectorsShared::JobStatus::FINISHED)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          modified_since: modified_since,
          access_token: access_token,
          cursors: cursors
        )

        idle_a_bit
      end

      it 'updates the cursors with cursors received from extractor' do
        expect(job).to receive(:update_cursors).with(cursors_after_extraction)

        job_runner.start_job(
          job: job,
          connector_class: connector_class,
          modified_since: modified_since,
          access_token: access_token,
          cursors: cursors
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
            modified_since: modified_since,
            access_token: access_token,
            cursors: cursors
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
            modified_since: modified_since,
            access_token: access_token,
            cursors: cursors
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
