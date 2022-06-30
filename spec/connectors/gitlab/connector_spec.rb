# frozen_string_literal: true

require 'hashie/mash'
require 'connectors/gitlab/connector'
require 'connectors/gitlab/custom_client'

describe Connectors::GitLab::Connector do
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:base_url) { Connectors::GitLab::DEFAULT_BASE_URL }
  let(:app_config) { Hashie::Mash.new(:gitlab => { :base_url => base_url, :api_token => 'some_token' }) }

  context '#source_status' do
    before do
      stub_const('App::Config', app_config)
    end
    it 'correctly returns true on 200' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 200, :body => user_json)
      result = subject.source_status

      expect(result).to_not be_nil
      expect(result[:status]).to eq('OK')
    end

    it 'correctly returns false on 401' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.source_status

      expect(result).to_not be_nil
      expect(result[:status]).to eq('FAILURE')
    end

    it 'correctly returns false on 400' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.source_status

      expect(result).to_not be_nil
      expect(result[:status]).to eq('FAILURE')
    end
  end
end
