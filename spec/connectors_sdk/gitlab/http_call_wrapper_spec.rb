# frozen_string_literal: true

require 'hashie/mash'
require 'connectors_sdk/gitlab/http_call_wrapper'

describe ConnectorsSdk::GitLab::HttpCallWrapper do

  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:base_url) { 'https://www.example.com' }

  context '#health_check' do
    it 'correctly returns true on 200' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 200, :body => user_json)
      result = subject.health_check({ :base_url => base_url })

      expect(result).to be_truthy
    end

    it 'correctly returns false on 401' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.health_check({ :base_url => base_url })

      expect(result).to be_falsey
    end

    it 'correctly returns false on 400' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.health_check({ :base_url => base_url })

      expect(result).to be_falsey
    end
  end
end
