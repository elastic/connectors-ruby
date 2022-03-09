# frozen_string_literal: true
#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'faraday'
require 'hashie'
require 'json'

require 'sinatra'
require 'sinatra/config_file'

require 'connectors_sdk/share_point/http_call_wrapper'
require 'connectors_sdk/share_point/authorization'
require 'connectors_app/errors'
require 'connectors_shared'
require 'connectors_app/config'

# Sinatra app
class ConnectorsWebApp < Sinatra::Base
  register Sinatra::ConfigFile
  config_file ConnectorsApp::CONFIG_FILE

  configure do
    set :raise_errors, settings.http['raise_errors']
    set :show_exceptions, settings.http['show_exceptions']
    set :port, settings.http['port']
    set :api_key, settings.http['api_key']
    set :deactivate_auth, settings.http['deactivate_auth']
  end

  before do
    Time.zone = ActiveSupport::TimeZone.new('UTC')
    # XXX to be removed
    return if settings.deactivate_auth

    raise StandardError.new 'You need to set an API key in the config file' if settings.environment != :test && settings.api_key == 'secret'

    auth = Rack::Auth::Basic::Request.new(request.env)

    # Check that the key matches
    return if auth.provided? && auth.basic? && auth.credentials && auth.credentials[1] == settings.api_key

    # We only support Basic for now
    if auth.provided? && auth.scheme != 'basic'
      code = ConnectorsApp::Errors::UNSUPPORTED_AUTH_SCHEME
      message = 'Unsupported authorization scheme'
    else
      code = ConnectorsApp::Errors::INVALID_API_KEY
      message = 'Invalid API key'
    end
    response = { errors: [{ message: message, code: code }] }.to_json
    halt(401, { 'Content-Type' => 'application/json' }, response)
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
    message = response_json.error? ? response_json.error.message : 'Connected to SharePoint'

    {
      extractor: {
        name: 'SharePoint'
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

    connector = ConnectorsSdk::SharePoint::HttpCallWrapper.new(
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
    authorization_uri = ConnectorsSdk::SharePoint::Authorization.authorization_uri(body)

    { oauth2redirect: authorization_uri.to_s }.to_json
  rescue StandardError => e
    status e.is_a?(ConnectorsShared::ClientError) ? 400 : 500
    { errors: [{ message: e.message }] }.to_json
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    content_type :json
    params = JSON.parse(request.body.read, symbolize_names: true)
    if params[:refresh_token] # FIXME: hmmmm not sure if it's the best way to move forward
      ConnectorsSdk::SharePoint::Authorization.refresh(params)
    else
      ConnectorsSdk::SharePoint::Authorization.access_token(params)
    end
  rescue StandardError => e
    status e.is_a?(ConnectorsShared::ClientError) ? 400 : 500
    { errors: [{ message: e.message }] }.to_json
  end

  post '/oauth2/refresh' do
    content_type :json
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    Connectors::Sharepoint::Authorization.refresh(params)
  rescue StandardError => e
    status case e
           when ConnectorsShared::ClientError
             400
           when ::Signet::AuthorizationError
             401
           else
             500
           end
    { errors: [{ message: e.message }] }.to_json
  end
end
