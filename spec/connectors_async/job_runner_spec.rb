#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_async/job_runner'

describe ConnectorsAsync::JobRunner do
  let(:job_runner) { described_class.new }

  context '#start_job' do
    let(:connector) { double }
    let(:modified_since) { nil }
    let(:access_token) { 'salad is OK' }
    let(:job) { double }
    let(:thread_executor_mock) { double }
    let(:extraction_time) { 0 }
    let(:connector_class) { double }

    before(:each) do
      allow(job).to receive(:update_status)

      allow(connector).to receive(:extract) do
        sleep(extraction_time)
      end

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
          access_token: access_token
        )

        end_time = Time.now

        expect(end_time - start_time).to be < 0.01
      end
    end
  end
end
