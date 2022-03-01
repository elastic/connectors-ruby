# frozen_string_literal: true

require 'faraday'
require 'hashie'
require 'sinatra'
require 'json'

require 'connectors/sharepoint/http_call_wrapper'
require 'signet'
require 'signet/oauth_2'
require 'signet/oauth_2/client'

# Sinatra app
class ConnectorsWebApp < Sinatra::Base
  get '/' do
    content_type :json
    { version: '1.0' }.to_json
  end

  get '/health' do
    content_type :json
    { healthy: 'yes' }.to_json
  end

  get '/status' do
    content_type :json

    # TODO: wait for other refactorings to replace this code in the right spot
    response = Faraday.get('https://graph.microsoft.com/v1.0/me')
    response_json = Hashie::Mash.new(JSON.parse(response.body))

    status = response_json.error? ? 'FAILURE' : 'OK'
    message = response_json.error? ? response_json.error.message : 'Connected to Sharepoint'

    {
      extractor: {
        name: 'Sharepoint'
      },
      contentProvider: {
        status: status,
        statusCode: response.status,
        message: message
      }
    }.to_json
  end

  post '/documents' do
    content_type :json
    params = JSON.parse(request.body.read)

    connector = Sharepoint::HttpCallWrapper.new(
      params
    )

    return { results: connector.get_document_batch, cursor: nil }.to_json
  end

  post '/download' do
    file = File.join(__dir__, 'cat.jpg')
    send_file(file, type: 'image/jpeg', disposition: 'inline')
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/init' do
    content_type :json
    body = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received client ID: #{body[:client_id]} and client secret: #{body[:client_secret]}"
    logger.info "Received redirect URL: #{params[:redirect_uri]}"
    authorization_uri = Sharepoint::Authorization.authorization_uri(body)

    { oauth2redirect: authorization_uri.to_s }.to_json
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    content_type :json
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    Sharepoint::Authorization.access_token(params)
  end
end
