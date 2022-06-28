# frozen_string_literal: true

require 'hashie/mash'
require 'connectors/gitlab/connector'

describe Connectors::GitLab::Connector do

  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:base_url) { 'https://www.example.com' }

  subject do
    Connectors::GitLab::Connector.new({ :base_url => base_url })
  end

  context '#source_status' do
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
