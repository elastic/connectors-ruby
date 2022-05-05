#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

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
require 'connectors_async'

Dir[File.join(__dir__, 'initializers/**/*.rb')].sort.each { |f| require f }

# Sinatra app
class ConnectorsWebApp < Sinatra::Base
  register Sinatra::ConfigFile
  config_file ConnectorsApp::CONFIG_FILE

  configure do
    set :raise_errors, false
    set :show_exceptions, false
    set :bind, settings.http['host']
    set :port, [ENV['PORT'], settings.http['port'], '9292'].detect(&:present?)
    set :api_key, settings.http['api_key']
    set :deactivate_auth, settings.http['deactivate_auth']
    set :connector_name, settings.http['connector']
    set :connector_class, ConnectorsSdk::Base::REGISTRY.connector_class(settings.http['connector'])
    set :job_store, ConnectorsAsync::JobStore.new
    set :job_runner, ConnectorsAsync::JobRunner.new
  end

  error do
    e = env['sinatra.error']
    err = case e
          when ConnectorsShared::ClientError
            ConnectorsShared::Error.new(400, 'BAD_REQUEST', e.message)
          when ConnectorsShared::InvalidTokenError
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

    @connector = settings.connector_class.new
    # XXX to be removed
    return if settings.deactivate_auth

    raise StandardError.new 'You need to set an API key in the config file' if ![:test, :development].include?(settings.environment) && settings.api_key == ConnectorsApp::DEFAULT_PASSWORD

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

  post '/status' do
    source_status = @connector.source_status(body_params)
    json(
      :extractor => { :name => @connector.name },
      :contentProvider => source_status
    )
  end

  post '/documents' do
    job_id = body_params[:job_id]

    if job_id
      job = settings.job_store.fetch_job(job_id)
    else
      job = settings.job_store.create_job

      settings.job_runner.start_job(
        job: job,
        connector: @connector,
        modified_since: body_params[:modified_since],
        access_token: body_params[:access_token]
      )
    end

    raise job.error if job.is_failed?

    docs = job.pop_batch

    #TODO: send error cause???
    json(
      :job_id => job.id,
      :status => job.status,
      :docs => docs
    )
  end

  post '/download' do
    @connector.download(body_params)
  end

  post '/deleted' do
    json :results => @connector.deleted(body_params)
  end

  post '/permissions' do
    json :results => @connector.permissions(body_params)
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/init' do
    logger.info "Received client ID: #{body_params[:client_id]} and client secret: #{body_params[:client_secret]}"
    logger.info "Received redirect URL: #{body_params[:redirect_uri]}"
    authorization_uri = @connector.authorization_uri(body_params)

    json :oauth2redirect => authorization_uri
  end

  # XXX remove `oauth2` from the name
  post '/oauth2/exchange' do
    logger.info "Received payload: #{body_params}"
    json @connector.access_token(body_params)
  end

  post '/oauth2/refresh' do
    logger.info "Received payload: #{body_params}"
    json @connector.refresh(body_params)
  end

  def body_params
    @body_params ||= JSON.parse(request.body.read, symbolize_names: true).with_indifferent_access
  end
end
