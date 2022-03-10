#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe ConnectorsSdk::SharePoint::Authorization do
  describe '.authorization_uri' do
    let(:params) { { :client_id => 'client_id' } }

    context 'with invalid params' do
      %w[client_id].each do |param|
        it "raises ClientError for missing #{param}" do
          expect { described_class.authorization_uri(params.except(param.to_sym)) }.to raise_error(ConnectorsShared::ClientError)
        end
      end
    end

    context 'with valid params' do
      let(:authorization_uri) { Addressable::URI.parse('http://www.example.com') }

      it 'returns authorization uri' do
        allow_any_instance_of(Signet::OAuth2::Client).to receive(:authorization_uri).and_return(authorization_uri)
        expect(described_class.authorization_uri(params)).to eq(authorization_uri.to_s)
      end
    end
  end

  describe '.access_token' do
    let(:params) do
      {
        :client_id => 'client_id',
        :client_secret => 'client_secret',
        :code => 'code',
        :redirect_uri => 'http://www.example.com'
      }
    end

    context 'with invalid params' do
      %w[client_id client_secret code redirect_uri].each do |param|
        it "raises ClientError for missing #{param}" do
          expect { described_class.access_token(params.except(param.to_sym)) }.to raise_error(ConnectorsShared::ClientError)
        end
      end
    end

    context 'with valid params' do
      let(:token_hash) do
        {
            :access_token => 'access_token',
            :refresh_token => 'refresh_token'
        }
      end

      it 'returns access token' do
        allow_any_instance_of(Signet::OAuth2::Client).to receive(:fetch_access_token).and_return(token_hash)
        expect(described_class.access_token(params)).to eq(token_hash.to_json)
      end
    end
  end

  describe '.refresh' do
    let(:params) do
      {
          :client_id => 'client_id',
          :client_secret => 'client_secret',
          :refresh_token => 'refresh_token',
          :redirect_uri => 'http://www.example.com'
      }
    end

    context 'with invalid params' do
      %w[client_id client_secret refresh_token redirect_uri].each do |param|
        it "raises ClientError for missing #{param}" do
          expect { described_class.access_token(params.except(param.to_sym)) }.to raise_error(ConnectorsShared::ClientError)
        end
      end
    end

    context 'with valid params' do
      context 'with valid refresh token' do
        let(:token_hash) do
          {
              :access_token => 'access_token',
              :refresh_token => 'refresh_token'
          }
        end

        it 'returns access token' do
          allow_any_instance_of(Signet::OAuth2::Client).to receive(:refresh!).and_return(token_hash)
          expect(described_class.refresh(params)).to eq(token_hash.to_json)
        end
      end

      context 'with expired refresh token' do
        let(:error) { 'error' }
        it 'returns authorization error' do
          allow_any_instance_of(Signet::OAuth2::Client).to receive(:refresh!).and_raise(Signet::AuthorizationError.new(error))
          expect { described_class.refresh(params) }.to raise_error(Signet::AuthorizationError)
        end
      end
    end
  end
end
