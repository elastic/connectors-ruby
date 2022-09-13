#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core'
require 'app/dispatcher'

describe App::Dispatcher do
  let(:scheduler) { double }
  let(:pool) { double }
  let(:job_runner) { double }

  before(:each) do
    allow(described_class).to receive(:scheduler).and_return(scheduler)
    allow(described_class).to receive(:pool).and_return(pool)

    allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)
    allow(pool).to receive(:post).and_yield
    allow(Core::SyncJobRunner).to receive(:new).and_return(job_runner)
    allow(Core::Heartbeat).to receive(:send)
    allow(job_runner).to receive(:execute)
    allow(Utility::ExceptionTracking).to receive(:log_exception)

    stub_const('App::Dispatcher::POLL_IDLING', 1)
    stub_const('App::Dispatcher::TERMINATION_TIMEOUT', 1)
  end

  after(:each) do
    described_class.instance_variable_set(:@running, Concurrent::AtomicBoolean.new(false))
  end

  describe '.start!' do
    context 'when it\'s called twice' do
      before(:each) do
        allow(described_class).to receive(:start_polling_jobs!)
        described_class.start!
      end

      it 'raises error' do
        expect { described_class.start! }.to raise_error
      end
    end

    context 'without native connectors' do
      before(:each) do
        allow(scheduler).to receive(:when_polling_jobs)
      end
      it 'starts no sync jobs' do
        expect(Core::Heartbeat).to_not receive(:send)
        expect(job_runner).to_not receive(:execute)
        described_class.start!
      end
    end

    context 'with native connectors' do
      let(:connector_settings) { double }
      let(:id) { '123' }
      let(:service_type) { 'example' }
      let(:index_name) { 'search-foobar' }

      before(:each) do
        allow(connector_settings).to receive(:id).and_return(id)
        allow(connector_settings).to receive(:service_type).and_return(service_type)
        allow(connector_settings).to receive(:index_name).and_return(index_name)

        allow(scheduler).to receive(:when_polling_jobs).and_yield(connector_settings, true)
        allow(Connectors::REGISTRY).to receive(:registered?).with(service_type).and_return(true)
      end

      it 'starts sync job' do
        expect(Core::Heartbeat).to receive(:send)
        expect(job_runner).to receive(:execute)
        expect { described_class.start! }.to_not raise_error
      end

      context 'when service type is not supported' do
        before(:each) do
          allow(Connectors::REGISTRY).to receive(:registered?).with(service_type).and_return(false)
        end

        it 'should not sync' do
          expect(Core::Heartbeat).to_not receive(:send)
          expect(job_runner).to_not receive(:execute)
          expect { described_class.start! }.to_not raise_error
        end
      end

      context 'when index name is empty' do
        let(:index_name) { '' }

        it 'should not sync' do
          expect(Core::Heartbeat).to_not receive(:send)
          expect(job_runner).to_not receive(:execute)
          expect { described_class.start! }.to_not raise_error
        end
      end

      context 'when index name is invalid' do
        let(:index_name) { 'foobar' }

        it 'should not sync' do
          expect(Core::Heartbeat).to_not receive(:send)
          expect(job_runner).to_not receive(:execute)
          expect { described_class.start! }.to_not raise_error
        end
      end

      context 'when sync throws an error' do
        before(:each) do
          allow(job_runner).to receive(:execute).and_raise('Oh no!')
        end

        it 'logs an error when execute fails' do
          expect(Utility::ExceptionTracking).to receive(:log_exception).with(anything, match(/123/))
          expect { described_class.start! }.to_not raise_error
        end
      end
    end
  end

  describe '.shutdown!' do
    before(:each) do
      allow(described_class).to receive(:start_polling_jobs!)
      described_class.start!
    end

    it 'shuts down correctly' do
      expect(scheduler).to receive(:shutdown)
      expect(pool).to receive(:shutdown)
      expect(pool).to receive(:wait_for_termination)
      described_class.shutdown!
    end
  end
end
