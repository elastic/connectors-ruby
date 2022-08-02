#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'yaml'
require 'app/worker'

class FakeSettings
  def index_name
    'index'
  end
end

describe App::Worker do
  it 'should raise error for invalid service type' do
    allow(App::Config).to receive(:[]).with(:disable_warnings).and_return(true)
    allow(App::Config).to receive(:[]).with(:service_type).and_return('foobar')
    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(nil)
    expect { described_class.start! }.to raise_error('foobar is not a supported connector')
  end

  shared_examples 'handle_warnings' do |disable_warnings, stderr|
    it 'should display warnings from the Elasticsearch lib' do
      allow_any_instance_of(Elasticsearch::Client).to receive(:elasticsearch_validation_request).and_raise(Elastic::Transport::Transport::Errors::Unauthorized)

      config = {
        :disable_warnings => disable_warnings,
        :service_type => 'stub_connector',
        :connector_id => '1',
        :elasticsearch => {
        :api_key => 'key',
        :hosts => 'http://notreallyaserver'
        }
      }

      App::Config = config # rubocop:disable Naming/ConstantName
      allow(App::Worker).to receive(:start_heartbeat_task)
      allow(App::Worker).to receive(:start_polling_jobs)

      allow(Core::ElasticConnectorActions).to receive(:ensure_connectors_index_exists)
      allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)
      expect(Core::ConnectorSettings).to receive(:fetch).and_return(FakeSettings.new)

      stub_request(:head, 'http://notreallyaserver:9200/.elastic-connectors-sync-jobs-v1')
        .to_return(status: 404, body: YAML.dump({}), headers: {})

      stub_request(:put, 'http://notreallyaserver:9200/.elastic-connectors-sync-jobs-v1')
        .to_return(status: 200, body: YAML.dump({}), headers: {})

      expect { described_class.start! }.to output(stderr).to_stderr
    end
  end

  context 'should display warnings from the Elasticsearch lib' do
    include_examples 'handle_warnings', false, /#{Elasticsearch::SECURITY_PRIVILEGES_VALIDATION_WARNING}/
  end

  context 'should discard warnings from the Elasticsearch lib by default' do
    include_examples 'handle_warnings', true, ''
  end
end
