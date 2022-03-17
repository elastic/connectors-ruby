# frozen_string_literal: true
#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'active_support/inflector'
require 'faraday'
require 'hashie'
require 'json'

require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/json'

require 'connectors_shared'
require 'connectors_app/config'
require 'connectors_sdk/base/registry'

Dir[File.join(__dir__, 'initializers/**/*.rb')].sort.each { |f| require f }

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
    set :connector_name, settings.http['connector']
    set :connector, ConnectorsSdk::Base::REGISTRY.connector(settings.http['connector'])
  end

  error do
    e = env['sinatra.error']
    err = case e
          when ConnectorsShared::ClientError
            ConnectorsShared::Error.new(400, 'BAD_REQUEST', e.message)
          when ConnectorsShared::SecretInvalidError
            ConnectorsShared::INVALID_ACCESS_TOKEN
          when ConnectorsShared::TokenRefreshFailedError
            ConnectorsShared::TOKEN_REFRESH_ERROR
          else
            ConnectorsShared::INTERNAL_SERVER_ERROR
          end
    status err.status_code
    json :errors => [err.to_h]
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
    error = auth.provided? && auth.scheme != 'basic' ? ConnectorsShared::UNSUPPORTED_AUTH_SCHEME : ConnectorsShared::INVALID_API_KEY
    response = { errors: [error.to_h] }.to_json
    halt(error.status_code, { 'Content-Type' => 'application/json' }, response)
  end

  get '/' do
    json(
      :connectors_version => settings.version,
      :connectors_repository => settings.repository,
      :connectors_revision => settings.revision,
      :connector_name => ActiveSupport::Inflector.camelize(settings.http['connector'])
    )
  end

  get '/health' do
    json :healthy => 'yes'
  end

  get '/status' do
    # TODO: wait for other refactorings to replace this code in the right spot
    response = Faraday.get('https://graph.microsoft.com/v1.0/me')
    response_json = Hashie::Mash.new(JSON.parse(response.body))

    status = response_json.error? ? 'FAILURE' : 'OK'
    message = response_json.error? ? response_json.error.message : 'Connected to SharePoint'

    json(
      :extractor => { :name => 'SharePoint' },
      :contentProvider => { :status => status, :statusCode => response.status, :message => message }
    )
  end

  post '/documents' do
    params = JSON.parse(request.body.read)

    original_cursors = (params.fetch('cursors', {}) || {}).as_json

    connector = settings.connector

    results = connector.document_batch(params)

    new_cursors = if connector.cursors.as_json != original_cursors
                    connector.cursors
                  else
                    {}
                  end

    json(
      :results => results,
      :cursors => new_cursors
    )
  end

  post '/download' do
    params = JSON.parse(request.body.read, :symbolize_names => true)
    settings.connector.download(params)
  end

  post '/deleted' do
    json :results => settings.connector.deleted(JSON.parse(request.body.read))
  end

  post '/permissions' do
    json :results => settings.connector.permissions(JSON.parse(request.body.read))
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/init' do
    body = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received client ID: #{body[:client_id]} and client secret: #{body[:client_secret]}"
    logger.info "Received redirect URL: #{body[:redirect_uri]}"
    authorization_uri = settings.connector.authorization_uri(body)

    json :oauth2redirect => authorization_uri
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    json settings.connector.access_token(params)
  end

  post '/oauth2/refresh' do
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    json settings.connector.refresh(params)
  end
end
