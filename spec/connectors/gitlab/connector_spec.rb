# frozen_string_literal: true

require 'connectors/gitlab/connector'
require 'connectors/gitlab/custom_client'
require 'spec_helper'

describe Connectors::GitLab::Connector do
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:base_url) { Connectors::GitLab::DEFAULT_BASE_URL }
  let(:app_config) do
    {
      :elasticsearch => { :api_key => 'hello-world', :hosts => 'localhost:9200' },
      :gitlab => { :api_token => 'some_token' }
    }
  end
  let(:remote_config) do
    {
      :base_url => { :value => base_url }
    }
  end

  subject do
    Connectors::GitLab::Connector.new(local_configuration: app_config, remote_configuration: remote_config)
  end

  it_behaves_like 'a connector'

  context '#is_healthy?' do
    it 'correctly returns true on 200' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 200, :body => user_json)
      result = subject.is_healthy?

      expect(result).to eq(true)
    end

    it 'correctly returns false on 401' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.is_healthy?

      expect(result).to eq(false)
    end

    it 'correctly returns false on 400' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.is_healthy?

      expect(result).to eq(false)
    end
  end

  context '#yield_documents' do
    let(:page_count) { 3 }
    let(:page_size) { 100 }

    let(:first_page_next_page_link) { 'https://next.page/1' }
    let(:second_page_next_page_link) { 'https://next.page/2' }
    let(:third_page_next_page_link) { 'https://next.page/3' }

    let(:extractor) { double }

    def create_data_page(ids)
      ids.map do |id|
        {
          :id => id,
          :something => "something-#{id}"
        }
      end
    end

    before(:each) do
      allow(Connectors::GitLab::Extractor).to receive(:new).and_return(extractor)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(nil)
        .and_yield(create_data_page(1..page_size))
        .and_return(first_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(first_page_next_page_link)
        .and_yield(create_data_page(page_size + 1..page_size * 2))
        .and_return(second_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(second_page_next_page_link)
        .and_yield(create_data_page(page_size * 2 + 1..page_size * 3))
        .and_return(third_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(third_page_next_page_link)
        .and_return(nil)
    end

    it 'extracts all documents' do
      docs = []

      subject.yield_documents { |doc| docs << doc }

      expect(docs.size).to eq(page_count * page_size)
    end
  end
end
