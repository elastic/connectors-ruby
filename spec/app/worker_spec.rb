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

class FakeSettings
  def index_name
    'index'
  end
end

describe App::Worker do
  it 'should raise error for invalid service type' do
    config = {
      :service_type => 'foobar',
      :connector_id => '1',
      :log_level => 'INFO',
      :elasticsearch => {
        :api_key => 'key',
        :hosts => 'http://notreallyaserver'
      }
    }
    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(nil)
    stub_const('App::Config', config)

    expect {
      Utility::Environment.set_execution_environment(config) do
        described_class.start!
      end
    }.to raise_error('foobar is not a supported connector')
  end

  shared_examples 'handle_warnings' do |disable_warnings, stderr|
    it "with disable_warnings=#{disable_warnings}" do
      # This call will raise a 401 when the lib checks the server, and that will create a warning
      expect_any_instance_of(Utility::EsClient).to receive(:elasticsearch_validation_request).and_raise(Elastic::Transport::Transport::Errors::Unauthorized)

      config = if disable_warnings
                 # This is the default behavior, so we don't pass
                 # disable_warnings to make sure it is set to true by default
                 {
                   :service_type => 'stub_connector',
                   :connector_id => '1',
                   :log_level => 'INFO',
                   :elasticsearch => {
                     :api_key => 'key',
                     :hosts => 'http://notreallyaserver'
                   }
                 }
               else
                 {
                   :service_type => 'stub_connector',
                   :log_level => 'INFO',
                   :connector_id => '1',
                   :elasticsearch => {
                     :api_key => 'key',
                     :hosts => 'http://notreallyaserver',
                     :disable_warnings => false
                   }
                 }
               end

      # mocking the worker so start! returns immediatly after the initial checks
      allow(App::Worker).to receive(:start_heartbeat_task)
      allow(App::Worker).to receive(:start_polling_jobs)

      # mocking some of the conversation between the worker and Elasticsearch
      expect(Core::ConnectorSettings).to receive(:fetch).and_return(FakeSettings.new)

      ['.elastic-connectors-sync-jobs-v1', 'index', '.elastic-connectors-v1'].each do |index|
        stub_request(:head, "http://notreallyaserver:9200/#{index}")
          .to_return(status: 404, body: YAML.dump({}), headers: {})
        stub_request(:put, "http://notreallyaserver:9200/#{index}")
          .to_return(status: 200, body: YAML.dump({}), headers: {})
      end

      stub_const('App::Config', config)

      # make sure we start with a fresh ESClient for the duration of the test
      expect(Core::ElasticConnectorActions).to receive(:client).at_least(:once).and_return(Utility::EsClient.new)

      # now let's see what is displated in stderr
      expect {
        Utility::Environment.set_execution_environment(config) do
          described_class.start!
        end
      }.to output(stderr).to_stderr
    end
  end

  context 'should display warnings from the Elasticsearch lib' do
    include_examples 'handle_warnings', false, /#{Elasticsearch::SECURITY_PRIVILEGES_VALIDATION_WARNING}/
  end

  context 'should discard warnings from the Elasticsearch lib by default' do
    include_examples 'handle_warnings', true, ''
  end
end
