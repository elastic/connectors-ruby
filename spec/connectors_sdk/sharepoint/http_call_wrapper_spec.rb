#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/share_point/http_call_wrapper'

describe ConnectorsSdk::SharePoint::HttpCallWrapper do
  describe '.compare_secrets' do
    let(:params) do
      {
        :secret => { :access_token => 'secret' },
        :other_secret => { :access_token => 'other_secret' }
      }
    end
    let(:client) { double }
    let(:user) { Hashie::Mash.new(:id => 1) }

    before(:each) do
      allow(subject).to receive(:client).and_return(client)
    end

    context 'when secrets are equivalent' do
      before(:each) do
        allow(client).to receive(:me).and_return(user)
      end

      it 'returns true' do
        expect(subject.compare_secrets(params)[:equivalent]).to be_truthy
      end
    end

    context 'when secrets are not equivalent' do
      let(:other_user) { Hashie::Mash.new(:id => 2) }

      before(:each) do
        allow(client).to receive(:me).and_return(user, other_user)
      end

      it 'returns false' do
        expect(subject.compare_secrets(params)[:equivalent]).to be_falsey
      end
    end
  end
end
