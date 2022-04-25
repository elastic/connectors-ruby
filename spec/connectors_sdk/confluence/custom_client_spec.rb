#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe ConnectorsSdk::Confluence::CustomClient do
  let(:auth_token) { 'auth_token' }
  let(:base_url) { 'http://localhost' }
  let(:client) do
    described_class.new(
      :base_url => base_url,
      :access_token => 'access_token'
    )
  end

  let!(:content_request) do
    stub_request(:get, "#{base_url}/rest/api/content/search").with(
      :query => {
        :cql => 'space="space" order by created asc',
        :start => 0,
        :expand => '',
        :limit => 50
      }
    ).and_return(:status => 200, :body => '{}')
  end

  let!(:content_by_id_request) do
    stub_request(:get, "#{base_url}/rest/api/content/1234").with(
      :query => {
        :status => 'any',
        :expand => described_class::CONTENT_EXPAND_FIELDS.join(',')
      }
    ).and_return(:status => 200, :body => '{}')
  end

  let!(:spaces_request) do
    stub_request(:get, "#{base_url}/rest/api/space").with(
      :query => {
        :start => 0,
        :limit => 50
      }
    ).and_return(:status => 200, :body => '{}')
  end

  let!(:search_request) do
    stub_request(:get, "#{base_url}/rest/api/search").with(
      :query => {
        :cql => 'space="space" order by created asc',
        :start => 0,
        :expand => '',
        :limit => 50
      }
    ).and_return(:status => 200, :body => '{}')
  end

  let!(:content_search_request) do
    stub_request(:get, "#{base_url}/rest/api/content/search").with(
      :query => {
        :cql => 'CQL',
        :expand => '',
        :limit => 25
      }
    ).and_return(:status => 200, :body => '{}')
  end

  it 'inherits from Atlassian' do
    expect(client.class.superclass).to eq(ConnectorsSdk::Atlassian::CustomClient)
  end

  it '#content_by_id' do
    client.content_by_id('1234')
    expect(content_by_id_request).to have_been_requested
  end

  it '#spaces' do
    client.spaces
    expect(spaces_request).to have_been_requested
  end

  it '#search' do
    client.search(:space => 'space')
    expect(search_request).to have_been_requested
  end

  it '#content_search' do
    client.content_search('CQL', :expand => [], :limit => 25)
    expect(content_search_request).to have_been_requested
  end

  describe '#content' do
    let(:next_value) { '/a-provided-endpoint?with=a_param' }

    let!(:content_next_value_request) do
      stub_request(:get, "#{base_url}/a-provided-endpoint").with(
        :query => {
          :with => 'a_param'
        }
      ).and_return(:status => 200, :body => '{}')
    end

    it 'issues a content search' do
      client.content(:space => 'space')
      expect(content_request).to have_been_requested
    end

    it 'prefers a next_value parameter' do
      client.content(:space => 'this does not matter', :next_value => next_value)
      expect(content_next_value_request).to have_been_requested
    end
  end

  describe 'error when non-200 response' do
    shared_examples_for(:failure) do
      it 'raises' do
        expect { client.content(:space => 'space') }.to raise_error(error)
      end
    end

    describe 'raises ServiceUnavailableError for 504' do
      let(:error) { ConnectorsSdk::Atlassian::CustomClient::ServiceUnavailableError }
      let!(:content_request) do
        stub_request(:get, "#{base_url}/rest/api/content/search")
          .with(query: hash_including({}))
          .and_return(:status => 504, :body => '{}')
      end

      it_behaves_like(:failure)
    end

    describe 'raises ContentConvertibleError for 400' do
      let(:error) { ConnectorsSdk::Atlassian::CustomClient::ContentConvertibleError }
      let!(:content_request) do
        stub_request(:get, "#{base_url}/rest/api/content/search")
          .with(query: hash_including({}))
          .and_return(:status => 400, :body => '{ "text": "is not ContentConvertible or API available" }')
      end

      it_behaves_like(:failure)
    end

    describe 'raises ClientError otherwise' do
      let(:error) { ConnectorsSdk::Atlassian::CustomClient::ClientError }
      let!(:content_request) do
        stub_request(:get, "#{base_url}/rest/api/content/search")
          .with(query: hash_including({}))
          .and_return(:status => 500, :body => '{}')
      end

      it_behaves_like(:failure)
    end
  end
end
