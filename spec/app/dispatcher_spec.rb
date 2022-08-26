#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'core'
require 'app/worker'
require 'app/dispatcher'

describe App::Dispatcher do
  let(:mock_scheduler) do
    double
  end

  let(:simple_pool) do
    Concurrent::ImmediateExecutor.new
  end

  let(:connector_id1) { '123' }
  let(:connector_id2) { '456' }

  let(:connector_settings1) { double }
  let(:connector_settings2) { double }

  let(:mock_job_runner) { double }

  before do
    allow(Core::ElasticConnectorActions).to receive(:ensure_connectors_index_exists)
    allow(Core::ElasticConnectorActions).to receive(:ensure_job_index_exists)
    allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)

    allow(Core::Heartbeat).to receive(:start_task)

    allow(Core::SyncJobRunner).to receive(:new).and_return(mock_job_runner)
    allow(mock_job_runner).to receive(:execute)

    subject.instance_variable_set(:@pool, simple_pool)
    stub_const('App::Dispatcher::POLL_IDLING', 1)
    stub_const('App::Dispatcher::TERMINATION_TIMEOUT', 1)
    stub_const('Core::SyncJobRunner', Core::SyncJobRunner)
  end

  before(:each) do
    subject.instance_variable_set(:@is_shutting_down, true) # prevent infinite loop - run just one cycle
    allow(Core::NativeScheduler).to receive(:new).and_return(mock_scheduler)
    allow(mock_scheduler).to receive(:when_triggered)
    allow(simple_pool).to receive(:post).and_call_original
    allow(Object).to receive(:sleep) # don't really want to sleep

    allow(Utility::ExceptionTracking).to receive(:log_exception).and_call_original

    allow(connector_settings1).to receive(:id).and_return(connector_id1)
    allow(connector_settings1).to receive(:index_name).and_return('connector1')
    allow(connector_settings2).to receive(:id).and_return(connector_id2)
    allow(connector_settings2).to receive(:index_name).and_return('connector2')

    [connector_settings1, connector_settings2].each { |cs| allow(cs).to receive(:service_type).and_return('example') }
  end

  describe '#start!' do
    context 'when no native connectors' do
      it 'starts no sync jobs' do
        subject.start!

        expect(subject.scheduler).to_not be_nil
        expect(simple_pool).to_not have_received(:post)
        expect(Core::Heartbeat).to_not have_received(:start_task)
      end
    end

    context 'when one native connector' do
      before(:each) do
        allow(mock_scheduler).to receive(:when_triggered).and_yield(connector_settings1)
      end

      it 'starts one sync job' do
        subject.start!

        expect(subject.scheduler).to_not be_nil
        expect(simple_pool).to have_received(:post)

        expect(Core::ElasticConnectorActions).to have_received(:ensure_job_index_exists).once
        expect(Core::ElasticConnectorActions).to have_received(:ensure_connectors_index_exists).once
        expect(Core::ElasticConnectorActions).to have_received(:ensure_content_index_exists).once

        expect(Core::Heartbeat).to have_received(:start_task).with(connector_id1, 'example').once
      end

      context 'when sync throws an error' do
        before(:each) do
          allow(mock_job_runner).to receive(:execute).and_raise('Oh no!')
        end
        it 'logs an error when execute fails' do
          subject.start!

          expect(Utility::ExceptionTracking).to have_received(:log_exception).with(anything, match(/123/))
        end
      end
    end
  end

  context 'when two native connectors' do
    before(:each) do
      allow(mock_scheduler).to receive(:when_triggered).and_yield(connector_settings1).and_yield(connector_settings2)
    end

    it 'starts two sync jobs' do
      subject.start!

      expect(subject.scheduler).to_not be_nil
      expect(simple_pool).to have_received(:post).twice

      expect(Core::ElasticConnectorActions).to have_received(:ensure_job_index_exists).once
      expect(Core::ElasticConnectorActions).to have_received(:ensure_connectors_index_exists).once
      expect(Core::ElasticConnectorActions).to have_received(:ensure_content_index_exists).twice

      expect(Core::Heartbeat).to have_received(:start_task).with(connector_id1, 'example').once
      expect(Core::Heartbeat).to have_received(:start_task).with(connector_id2, 'example').once
    end
  end

  describe '#shutdown' do
    before(:each) do
      allow(simple_pool).to receive(:shutdown)
      subject.instance_variable_set(:@is_shutting_down, false)
    end

    it 'shutdowns correctly' do
      subject.shutdown

      expect(simple_pool).to have_received(:shutdown)
      expect(subject.instance_variable_get(:@is_shutting_down)).to eq(true)
    end
  end
end
