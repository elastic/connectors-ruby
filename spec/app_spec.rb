# frozen_string_literal: true

require 'app/app'
require 'connectors_app/errors'
require 'connectors_app/version'

RSpec.describe ConnectorsWebApp do
  include Rack::Test::Methods

  let(:app) { ConnectorsWebApp }

  def expect_json(response, json)
    expect(json(response)).to eq json
  end

  def json(response)
    Hashie::Mash.new(JSON.parse(response.body))
  end

  before(:each) do
    allow(ConnectorsWebApp.settings).to receive(:deactivate_auth).and_return(false)
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
      basic_authorize 'ent-search', 'secret'
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
      basic_authorize 'ent-search', 'secret'
      get '/'
    }

    it 'returns the connectors metadata' do
      expect(response.status).to eq 200
      expect(json(response)['version']).to eq ConnectorsApp::VERSION
    end
  end

  describe 'GET /status' do
    let(:response) {
      basic_authorize 'ent-search', 'secret'
      get '/status'
    }

    it 'returns status 200 OK' do
      stub_request(:get, 'https://graph.microsoft.com/v1.0/me')
        .with { true }
        .to_return(status: 200, body: JSON.generate({}))

      expect(response.status).to eq 200
    end
  end

  describe 'POST /oauth2/init' do
    context 'with valid request' do
      let(:params) { { :client_id => 'client id' } }
      let(:authorization_uri) { 'authorization_uri' }

      it 'returns authorization uri' do
        allow(ConnectorsSdk::SharePoint::Authorization).to receive(:authorization_uri).and_return(authorization_uri)

        basic_authorize 'ent-search', 'secret'
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

        basic_authorize 'ent-search', 'secret'
        response = post('/oauth2/init', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' })
        expect(response.status).to eq(400)
        expect(json(response)['errors'].first['message']).to eq(error)
      end
    end
  end

  describe 'Oauth2 dance' do
    it 'does the oauth2 dance' do
      # we call /oauth2/init with the client_id and client_secret
      params = { :client_id => 'client id', :client_secret => 'secret', :redirect_uri => 'http://here' }
      basic_authorize 'ent-search', 'secret'
      response_json = JSON.parse(post('/oauth2/init', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' }).body)
      url = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?access_type=offline&client_id=client%20id&prompt=consent&redirect_uri=http://here&response_type=code&scope=User.ReadBasic.All%20Group.Read.All%20Directory.AccessAsUser.All%20Files.Read%20Files.Read.All%20Sites.Read.All%20offline_access'
      expect(response_json['oauth2redirect']).to eq url

      # the user gets redirected, and we get a code
      authorization_code = 'the code'

      # we exchange the code with an access token
      stub_request(:post, 'https://login.microsoftonline.com/common/oauth2/v2.0/token')
        .with { true }
        .to_return(status: 200, body: JSON.generate({ :token => 'TOKEN' }), headers: { 'Content-Type' => 'application/json' })

      params = { :client_id => 'client id', :client_secret => 'secret', :code => authorization_code, :redirect_uri => 'http://here' }
      response_json = JSON.parse(post('/oauth2/exchange', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' }).body)
      expect(response_json['token']).to eq 'TOKEN'
    end
  end
end
