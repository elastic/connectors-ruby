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
  let(:native_connector) do
    {
      "id": '1234567890',
      "api_key_id": nil,
      "configuration": {},
      "index_name": 'search-test',
      "language": nil,
      "last_seen": nil,
      "last_sync_error": nil,
      "last_sync_status": nil,
      "last_synced": nil,
      "name": 'test',
      "scheduling": {
        "enabled": false,
        "interval": '0 0 0 * * ?'
      },
      "service_type": 'example',
      "status": 'created',
      "sync_now": false,
      "is_native": true
    }.with_indifferent_access
  end

  let(:mock_worker) do
    double
  end

  let(:mock_scheduler) do
    Concurrent::ImmediateExecutor.new
  end

  before do
    subject.instance_variable_set(:@pool, mock_scheduler)
    stub_const('App::Dispatcher::POLL_IDLING', 1)
    stub_const('App::Dispatcher::TERMINATION_TIMEOUT', 1)
  end

  before(:each) do
    subject.instance_variable_set(:@is_shutting_down, true) # prevent infinite loop - run just one cycle
    allow(App::Worker).to receive(:new).and_return(mock_worker)
    allow(mock_worker).to receive(:start!)
  end

  describe '#start!' do
    context 'when no native connectors are returned' do
      it 'starts no workers' do
        allow(Core::ElasticConnectorActions).to receive(:native_connectors).and_return([])
        subject.start!

        expect(subject.workers.length).to eq(0)
      end
    end

    context 'when there is one native connector' do
      it 'starts one worker' do
        allow(Core::ElasticConnectorActions).to receive(:native_connectors).and_return([native_connector])
        subject.start!

        expect(subject.workers.length).to eq(1)
        expect(mock_worker).to have_received(:start!).exactly(1).times
      end
    end

    context 'when there are several native connectors' do
      let(:native_connector_one) do
        native_connector.dup.merge :id => '0987654321'
      end
      it 'starts several workers' do
        allow(Core::ElasticConnectorActions).to receive(:native_connectors).and_return([native_connector, native_connector_one])
        subject.start!

        expect(subject.workers.length).to eq(2)
        expect(mock_worker).to have_received(:start!).exactly(2).times
      end
    end

    context 'when native connectors search throws an error' do
      it 'starts no workers' do
        allow(Core::ElasticConnectorActions).to receive(:native_connectors).and_raise(StandardError)
        subject.start!

        expect(subject.workers.length).to eq(0)
      end
    end
  end

  describe '#shutdown' do
    before(:each) do
      allow(mock_scheduler).to receive(:shutdown)
      subject.instance_variable_set(:@is_shutting_down, false)
    end

    it 'shutdowns correctly' do
      subject.shutdown

      expect(mock_scheduler).to have_received(:shutdown)
      expect(subject.instance_variable_get(:@is_shutting_down)).to eq(true)
    end
  end
end
