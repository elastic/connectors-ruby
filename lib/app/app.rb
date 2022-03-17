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
require 'sinatra/json'

require 'connectors_app/errors'
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
    content_type :json
    status 500
    e = env['sinatra.error']
    backtrace = "Application error\n#{e}\n#{e.backtrace.join("\n")}"

    json(
      :errors => [
        {
          :message => 'Internal Server Error',
          :code => ConnectorsApp::Errors::INTERNAL_SERVER_ERROR,
          :backtrace => backtrace
        }
      ]
    )
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
    json(
      :connectors_version => settings.version,
      :connectors_repository => settings.repository,
      :connectors_revision => settings.revision
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
  rescue ConnectorsShared::ClientError => e
    render_exception(400, e.message)
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    json settings.connector.access_token(params)
  rescue ConnectorsShared::ClientError => e
    render_exception(400, e.message)
  end

  post '/oauth2/refresh' do
    params = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received payload: #{params}"
    json settings.connector.refresh(params)
  rescue ConnectorsShared::ClientError => e
    render_exception(400, e.message)
  rescue ::Signet::AuthorizationError => e
    render_exception(401, e.message)
  end

  def render_exception(status_code, message)
    status status_code
    json :errors => [{ message: message }]
  end
end
