# frozen_string_literal: true

require 'spec_helper'
require 'app/app'

ENV['APP_ENV'] = 'test'

RSpec.describe ConnectorsWebApp do
  include Rack::Test::Methods

  let(:app) { ConnectorsWebApp }

  describe 'GET /status' do
    let(:response) { get '/status' }

    it 'returns status 200 OK' do
      stub_request(:get, 'https://graph.microsoft.com/v1.0/me')
        .with { true }
        .to_return(status: 200, body: JSON.generate({}))

      puts(response.body)
      expect(response.status).to eq 200
    end
  end

  describe "Oauth2 dance" do
    it "does the oauth2 dance" do

      # we call /oauth2/init with the client_id and client_secret
      params = {:client_id => 'client id', :client_secret => 'secret', :redirect_uri => 'http://here'}
      response_json = JSON.parse(post('/oauth2/init', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' }).body)
      url = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?access_type=offline&client_id=client%20id&prompt=consent&redirect_uri=http://here&response_type=code&scope=User.ReadBasic.All%20Group.Read.All%20Directory.AccessAsUser.All%20Files.Read%20Files.Read.All%20Sites.Read.All%20offline_access&state=null"
      expect(response_json['oauth2redirect']).to eq url

      # the user gets redirected, and we get a code
      authorization_code = 'the code'

      # we exchange the code with an access token
      stub_request(:post, 'https://login.microsoftonline.com/common/oauth2/v2.0/token')
        .with { true }
        .to_return(status: 200, body: JSON.generate({}))

      params = {:client_id => 'client id', :client_secret => 'secret', :code =>  authorization_code}
      response_json = JSON.parse(post('/oauth2/exchange', JSON.generate(params), { 'CONTENT_TYPE' => 'application/json' }).body)

    end
  end

end
