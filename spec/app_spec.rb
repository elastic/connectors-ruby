# frozen_string_literal: true

require 'app/app'
require 'connectors_app/errors'
require 'connectors_app/version'

RSpec.describe ConnectorsWebApp do
  include Rack::Test::Methods

  let(:app) { ConnectorsWebApp }
  let(:api_key) { 'api_key' }

  def expect_json(response, json)
    expect(json(response)).to eq json
  end

  def json(response)
    Hashie::Mash.new(JSON.parse(response.body))
  end

  before(:each) do
    allow(ConnectorsWebApp.settings).to receive(:deactivate_auth).and_return(false)
    allow(ConnectorsWebApp.settings).to receive(:api_key).and_return(api_key)
  end

  describe 'Catch all' do
    it 'returns a 500 in JSON, on any error' do
      # this will break the Sinatra server on GET /status
      allow(Faraday).to receive(:get) { raise StandardError }

      allow(ConnectorsWebApp.settings).to receive(:raise_errors).and_return(false)
      allow(ConnectorsWebApp.settings).to receive(:show_exceptions).and_return(false)

      basic_authorize 'ent-search', api_key
      response = get '/status'
      expect(response.status).to eq 500
      response = json(response)
      expect(response['errors'][0]['code']).to eq ConnectorsApp::Errors::INTERNAL_SERVER_ERROR
    end
  end

  describe 'Authorization /' do
    let(:bad_auth) {
      { 'errors' => [
        { 'code' => ConnectorsApp::Errors::INVALID_API_KEY,
          'message' => 'Invalid API key' }
      ] }
    }

    let(:unsupported_auth) {
      { 'errors' => [
        { 'code' => ConnectorsApp::Errors::UNSUPPORTED_AUTH_SCHEME,
          'message' => 'Unsupported authorization scheme' }
      ] }
    }

    it 'returns a 401 when Basic auth misses' do
      response = get '/'
      expect(response.status).to eq 401
      expect_json(response, bad_auth)
    end

    it 'returns a 200 when Basic auth is OK' do
      basic_authorize 'ent-search', api_key
      response = get '/'
      expect(response.status).to eq 200
    end

    it 'returns a 401 when Basic auth is wrong' do
      basic_authorize 'ent-search', 'bad_secret'
      response = get '/'
      expect(response.status).to eq 401
      expect_json(response, bad_auth)
    end

    it 'returns a 401 on malformed Basic auth' do
      basic_authorize 'ent-search', nil
      response = get '/'
      expect(response.status).to eq 401
      expect_json(response, bad_auth)
    end

    it 'returns a 401 on unsupported auth scheme' do
      header('Authorization', 'Bearer TOKEN')
      response = get '/'
      expect(response.status).to eq 401
      expect_json(response, unsupported_auth)
    end
  end

  describe 'GET /' do
    let(:response) {
      basic_authorize 'ent-search', api_key
      get '/'
    }

    it 'returns the connectors metadata' do
      expect(response.status).to eq 200
      expect(json(response)['connectors_version']).to eq ConnectorsApp::VERSION
      expect(json(response)['connectors_revision']).to eq ConnectorsApp::Config['revision']
      expect(json(response)['connectors_repository']).to eq ConnectorsApp::Config['repository']
      expect(json(response)['connector_name']).to eq 'SharePoint'
    end
  end

  describe 'GET /status' do
    let(:response) {
      basic_authorize 'ent-search', api_key
      get '/status'
    }

    it 'returns status 200 OK' do
      stub_request(:get, 'https://graph.microsoft.com/v1.0/me')
        .with { true }
        .to_return(status: 200, body: JSON.generate({}))

      expect(response.status).to eq 200
    end
  end

  describe 'POST /deleted' do
    let(:params) { { :ids => %w[id1 id2], :access_token => 'access token' } }

    it 'returns deleted ids' do
      allow_any_instance_of(ConnectorsSdk::SharePoint::HttpCallWrapper).to receive(:deleted).and_return(['id1'])

      basic_authorize 'ent-search', api_key
      response = post('/deleted', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
      expect(response).to be_successful
      expect(json(response)['results']).to_not be_empty
    end
  end

  describe 'POST /permissions' do
    let(:params) { { :user_id => 'id', :access_token => 'access token' } }

    it 'returns deleted ids' do
      allow_any_instance_of(ConnectorsSdk::SharePoint::HttpCallWrapper).to receive(:permissions).and_return(%w[permission1 permission2])

      basic_authorize 'ent-search', api_key
      response = post('/permissions', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
      expect(response).to be_successful
      expect(json(response)['results']).to_not be_empty
    end
  end

  describe 'POST /oauth2/init' do
    context 'with valid request' do
      let(:params) { { :client_id => 'client id' } }
      let(:authorization_uri) { 'authorization_uri' }

      it 'returns authorization uri' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:authorization_uri).and_return(authorization_uri)

        basic_authorize 'ent-search', api_key
        response = post('/oauth2/init', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response).to be_successful
        expect(json(response)['oauth2redirect']).to eq(authorization_uri)
      end
    end

    context 'with invalid request' do
      let(:params) { {} }
      let(:error) { 'error' }

      it 'returns bad request' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:authorization_uri).and_raise(ConnectorsShared::ClientError.new(error))

        basic_authorize 'ent-search', api_key
        response = post('/oauth2/init', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response.status).to eq(400)
        expect(json(response)['errors'].first['message']).to eq(error)
      end
    end
  end

  describe 'POST /oauth2/exchange' do
    context 'with valid request' do
      let(:params) { { :client_id => 'client id', :client_secret => 'client_secret', :code => 'code', :redirect_uri => 'http://here' } }
      let(:token_hash) { { :access_token => 'access_token', :refresh_token => 'refresh_token' } }

      it 'returns tokens' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:access_token).and_return(token_hash)

        basic_authorize 'ent-search', api_key
        response = post('/oauth2/exchange', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response).to be_successful
        expect(json(response)['access_token']).to eq(token_hash[:access_token])
        expect(json(response)['refresh_token']).to eq(token_hash[:refresh_token])
      end
    end

    context 'with invalid request' do
      let(:params) { {} }
      let(:error) { 'error' }

      it 'returns bad request' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:access_token).and_raise(ConnectorsShared::ClientError.new(error))

        basic_authorize 'ent-search', api_key
        response = post('/oauth2/exchange', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response.status).to eq(400)
        expect(json(response)['errors'].first['message']).to eq(error)
      end
    end
  end

  describe 'POST /oauth2/refresh' do
    context 'with valid request' do
      let(:params) { { :client_id => 'client id', :client_secret => 'client_secret', :refresh_token => 'refresh_token', :redirect_uri => 'http://here' } }

      context 'with valid refresh token' do
        let(:token_hash) { { :access_token => 'access_token', :refresh_token => 'refresh_token' } }

        it 'returns tokens' do
          allow(ConnectorsSdk::SharePoint::Authorization).to receive(:refresh).and_return(token_hash)

          basic_authorize 'ent-search', api_key
          response = post('/oauth2/refresh', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
          expect(response).to be_successful
          expect(json(response)['access_token']).to eq(token_hash[:access_token])
          expect(json(response)['refresh_token']).to eq(token_hash[:refresh_token])
        end
      end

      context 'with expired refresh token' do
        let(:error) { 'error' }

        it 'returns 401' do
          allow(ConnectorsSdk::SharePoint::Authorization).to receive(:refresh).and_raise(Signet::AuthorizationError.new(error))

          basic_authorize 'ent-search', api_key
          response = post('/oauth2/refresh', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
          expect(response.status).to eq(401)
          expect(json(response)['errors'].first['message']).to eq(error)
        end
      end
    end

    context 'with invalid request' do
      let(:params) { {} }
      let(:error) { 'error' }

      it 'returns bad request' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:refresh).and_raise(ConnectorsShared::ClientError.new(error))

        basic_authorize 'ent-search', api_key
        response = post('/oauth2/refresh', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response.status).to eq(400)
        expect(json(response)['errors'].first['message']).to eq(error)
      end
    end
  end

  describe 'POST /download' do
    let(:http_call_wrapper_mock) { double }

    before(:each) do
      allow(ConnectorsSdk::SharePoint::HttpCallWrapper).to receive(:new).and_return(http_call_wrapper_mock)
      basic_authorize 'ent-search', api_key
    end

    context 'when valid parameters are passed' do
      let(:params) { { :a => 'b', :c => 'd' } }
      let(:file_content) { 'this is the file content, right?' }

      it 'calls HttpCallWrapper.download' do
        expect(http_call_wrapper_mock).to receive(:download)

        post('/download', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
      end

      it 'returns a successful response' do
        expect(http_call_wrapper_mock).to receive(:download)

        response = post('/download', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })

        expect(response).to be_ok
      end

      it 'returns the result of HttpCallWrapper.download' do
        allow(http_call_wrapper_mock).to receive(:download).and_return(file_content)

        response = post('/download', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })

        expect(response.body).to eq(file_content)
      end
    end

    context 'when JSON.parse raises an error' do
      before(:each) do
        allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
      end

      it 'raises this error' do
        expect { post('/download', '{}', { 'CONTENT_TYPE' => 'application/json' }) }.to raise_error(JSON::ParserError)
      end
    end

    context 'when HttpCallWrapper.download raises an error' do
      let(:params) { { :a => 'b', :c => 'd' } }
      let(:error_class) { ArgumentError }
      before(:each) do
        expect(http_call_wrapper_mock).to receive(:download).and_raise(error_class)
      end

      it 'raises this error' do
        expect { post('/download', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' }) }.to raise_error(error_class)
      end
    end
  end
end
