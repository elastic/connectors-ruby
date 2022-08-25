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

  let(:mock_pool) do
    Concurrent::ImmediateExecutor.new
  end

  let(:connector_id1) { '123' }
  let(:connector_id2) { '456' }

  let(:connector_settings1) { double }
  let(:connector_settings2) { double }

  before do
    subject.instance_variable_set(:@pool, mock_pool)
    stub_const('App::Dispatcher::POLL_IDLING', 1)
    stub_const('App::Dispatcher::TERMINATION_TIMEOUT', 1)
  end

  before(:each) do
    subject.instance_variable_set(:@is_shutting_down, true) # prevent infinite loop - run just one cycle
    allow(Core::NativeScheduler).to receive(:new).and_return(mock_scheduler)
    allow(mock_scheduler).to receive(:when_triggered)
    allow(mock_pool).to receive(:post)
    allow(Object).to receive(:sleep) # don't really want to sleep

    allow(connector_settings1).to receive(:[]).with(:id).and_return(connector_id1)
    allow(connector_settings2).to receive(:[]).with(:id).and_return(connector_id2)
    [connector_settings1, connector_settings2].each { |cs| allow(cs).to receive(:service_type).and_return('example') }
  end

  describe '#start!' do
    context 'when no native connectors' do
      it 'starts no sync jobs' do
        subject.start!

        expect(subject.scheduler).to_not be_nil
        expect(mock_pool).to_not have_received(:post)
      end
    end

    context 'when one native connector' do
      before(:each) do
        allow(mock_scheduler).to receive(:when_triggered).and_yield(connector_settings1)
      end

      it 'starts one sync job' do
        subject.start!

        expect(subject.scheduler).to_not be_nil
        expect(mock_pool).to have_received(:post)
      end
    end

    context 'when two native connectors' do
      before(:each) do
        allow(mock_scheduler).to receive(:when_triggered).and_yield(connector_settings1).and_yield(connector_settings2)
      end

      it 'starts one sync job' do
        subject.start!

        expect(subject.scheduler).to_not be_nil
        expect(mock_pool).to have_received(:post).twice
      end
    end
  end

  describe '#shutdown' do
    before(:each) do
      allow(mock_pool).to receive(:shutdown)
      subject.instance_variable_set(:@is_shutting_down, false)
    end

    it 'shutdowns correctly' do
      subject.shutdown

      expect(mock_pool).to have_received(:shutdown)
      expect(subject.instance_variable_get(:@is_shutting_down)).to eq(true)
    end
  end
end
