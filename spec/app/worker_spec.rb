#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'yaml'
require 'app/worker'
require 'utility/logger'
require 'utility/environment'

describe App::Worker do
  let(:connector_id) { '1' }
  let(:service_type) { 'foobar' }
  let(:content_index_name) { 'recent-data-ingestion-index' }
  let(:config) do
    {
      :service_type => service_type,
      :connector_id => connector_id,
      :log_level => 'INFO',
      :elasticsearch => {
        :api_key => 'key',
        :hosts => 'http://notreallyaserver'
      }
    }
  end

  let(:connector_settings) do
    double
  end

  let(:connector_class) do
    double
  end

  let(:scheduler) do
    double
  end

  let(:sync_job_runner) do
    double
  end

  let(:timer_task) do
    double
  end

  subject do
    App::Worker.new(connector_id: connector_id, service_type: service_type, is_native: false)
  end

  before(:each) do
    stub_const('App::Config', config)

    allow(connector_settings).to receive(:id).and_return(connector_id)
    allow(connector_settings).to receive(:index_name).and_return(content_index_name)

    allow(Core::ElasticConnectorActions).to receive(:ensure_connectors_index_exists)
    allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)
    allow(Core::ElasticConnectorActions).to receive(:ensure_job_index_exists)

    allow(Core::ConnectorSettings).to receive(:fetch).and_return(connector_settings)

    allow(Connectors::REGISTRY).to receive(:registered?).with(service_type).and_return(connector_class)

    allow(Core::Scheduler).to receive(:new).and_return(scheduler)
    allow(scheduler).to receive(:when_triggered).and_yield(connector_settings)

    allow(Core::SyncJobRunner).to receive(:new).and_return(sync_job_runner)
    allow(sync_job_runner).to receive(:execute)

    allow(Core::Heartbeat).to receive(:start_task)
  end

  describe '#start' do
    context 'when valid setup is provided' do
      it 'ensures necessary indices are created' do
        expect(Core::ElasticConnectorActions).to receive(:ensure_connectors_index_exists)
        expect(Core::ElasticConnectorActions).to receive(:ensure_job_index_exists)
        expect(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists).with(content_index_name)

        subject.start!
      end

      it 'starts sync job runner' do
        expect(sync_job_runner).to receive(:execute)
        subject.start!
      end
    end

    context 'when connector settings could not be fetched' do
      let(:error) { 'oh no!' }

      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch).and_raise(error)
      end

      it 'crashes with the raised error' do
        expect { subject.start! }.to raise_error(error)
      end
    end

    context 'when invalid service type is provided' do
      before(:each) do
        allow(Connectors::REGISTRY).to receive(:registered?).with(service_type).and_return(nil)
      end

      it 'should raise error for invalid service type' do
        expect {
          subject.start!
        }.to raise_error("#{service_type} is not a supported connector")
      end
    end

    context 'when Core::ElasticConnectorActions raises elastic unauthorized error' do
      let(:elastic_error_message) { 'Something really bad happened' }
      before(:each) do
        allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists).and_raise(Elastic::Transport::Transport::Errors::Unauthorized.new(elastic_error_message))
      end

      it 'raises a new more user-friendly error' do
        expect {
          subject.start!
        }.to raise_error(/#{elastic_error_message}/)
      end
    end

    context 'when scheduler does not yield' do
      before(:each) do
        allow(scheduler).to receive(:when_triggered)
      end

      it 'does not trigger the connector' do
        expect(sync_job_runner).to_not receive(:execute)

        subject.start!
      end
    end
  end
end
