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
end
