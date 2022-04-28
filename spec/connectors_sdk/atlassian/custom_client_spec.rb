#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe ConnectorsSdk::Atlassian::CustomClient do
  let(:auth_token) { 'auth_token' }
  let(:base_url) { 'http://localhost' }
  let(:access_token) { 'access token' }
  let(:client) do
    described_class.new(
      :base_url => base_url,
      :access_token => access_token
    )
  end

  describe '#download' do
    let(:url) { 'things' }

    it 'will download contents from a url' do
      expect(client.http_client).to receive(:get).once.ordered.and_return(Hashie::Mash.new(:status => 200, :body => '{}'))
      expect(client.download(url).status).to eql(200)
    end

    it 'will follow a redirect' do
      expect(client.middleware).to include(FaradayMiddleware::FollowRedirects)
    end
  end
end
