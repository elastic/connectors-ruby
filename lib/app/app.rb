# frozen_string_literal: true

require 'faraday'
require 'hashie'
require 'json'

require 'sinatra'
require 'sinatra/config_file'

require 'connectors/sharepoint/http_call_wrapper'
require 'connectors/sharepoint/authorization'
require 'connectors_shared'
require 'config'

# Sinatra app
class ConnectorsWebApp < Sinatra::Base
  register Sinatra::ConfigFile
  config_file Connectors::CONFIG_FILE

  configure do
    set :raise_errors, settings.http['raise_errors']
    set :show_exceptions, settings.http['show_exceptions']
    set :port, settings.http['port']
  end

  get '/' do
    content_type :json
    {
      version: settings.version,
      repository: settings.repository,
      revision: settings.revision
    }.to_json
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

    connector = Connectors::Sharepoint::HttpCallWrapper.new(
      params
    )

    return { results: connector.document_batch, cursor: nil }.to_json
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
    logger.info "Received redirect URL: #{body[:redirect_uri]}"
    authorization_uri = Connectors::Sharepoint::Authorization.authorization_uri(body)

    { oauth2redirect: authorization_uri.to_s }.to_json
  rescue StandardError => e
    status e.is_a?(ConnectorsShared::ClientError) ? 400 : 500
    { errors: [{ message: e.message }] }.to_json
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    content_type :json
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    Connectors::Sharepoint::Authorization.access_token(params)
  rescue StandardError => e
    status e.is_a?(ConnectorsShared::ClientError) ? 400 : 500
    { errors: [{ message: e.message }] }.to_json
  end
end
