#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/custom_client'

describe ConnectorsSdk::Base::CustomClient do
  let(:base_url) { 'http://localhost' }
  let(:client) { described_class.new(:base_url => base_url) }

  it '#get' do
    get_request = stub_request(:get, 'http://localhost').to_return(:status => 200)
    client.get('')
    expect(get_request).to have_been_requested.at_least_once
  end

  it '#post' do
    post_request = stub_request(:post, 'http://localhost').to_return(:status => 200)
    client.post('', {})
    expect(post_request).to have_been_requested.at_least_once
  end

  it '#put' do
    put_request = stub_request(:put, 'http://localhost').to_return(:status => 200)
    client.put('', {})
    expect(put_request).to have_been_requested.at_least_once
  end

  it '#delete' do
    delete_request = stub_request(:delete, 'http://localhost').to_return(:status => 200)
    client.delete('')
    expect(delete_request).to have_been_requested.at_least_once
  end

  context 'retries' do
    it 'retries on timeout response' do
      stubbed_request = stub_request(:get, 'http://localhost')
        .to_timeout.then
        .to_return(:status => 200)

      client.get('')
      expect(stubbed_request).to have_been_requested.twice
    end

    it 'only retries MAX_RETRIES times' do
      max = ConnectorsSdk::Base::CustomClient::MAX_RETRIES
      stubbed_request = (max + 5).times.each_with_object(stub_request(:get, 'http://localhost')) do |_, stub|
        stub.to_timeout.then
      end.to_return(:status => 200)
      expect { client.get('') }.to raise_error(Faraday::TimeoutError)
      expect(stubbed_request).to have_been_requested.times(max + 1) # original + "retries"
    end
  end

  describe 'ensuring auth is fresh' do
    let(:refresh_lambda) { ->(_client) { refresh_double.the_big_red_button } }
    let(:refresh_double) { double(:the_big_red_button => :kaboom) }

    it 'does not require refresh logic' do
      expect(refresh_double).not_to receive(:the_big_red_button)

      stub_request(:get, 'http://localhost').to_return(:status => 200)
      client.get('')
    end

    context 'auth refresh logic is provided' do
      let(:client) { described_class.new(:base_url => base_url, :ensure_fresh_auth => refresh_lambda) }

      it 'will use refresh logic when supplied' do
        expect(refresh_double).to receive(:the_big_red_button)

        stub_request(:get, 'http://localhost').to_return(:status => 200)
        client.get('')
      end
    end
  end

  describe '#request_with_throttling' do
    let(:url) { '/test' }

    context 'when request is successful' do
      it 'returns 200' do
        stub_request(:get, "#{base_url}#{url}").to_return(:status => 200)
        response = client.send(:request_with_throttling, :get, url)
        expect(response).to be_success
      end
    end

    context 'when rate limit is reached' do
      it 'raises ThrottlingError' do
        stub_request(:get, "#{base_url}#{url}").to_return(:status => 429, :headers => { 'Retry-After': 0 })
        expect { client.send(:request_with_throttling, :get, url) }.to raise_error(ConnectorsShared::ThrottlingError)
      end
    end
  end
end
