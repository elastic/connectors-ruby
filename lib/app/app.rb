# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'connectors/sharepoint/sharepoint'
require 'signet'
require 'signet/oauth_2'
require 'signet/oauth_2/client'

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
  { status: 'IDLING' }.to_json
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

post '/oauth2/init' do
  content_type :json
  params = JSON.parse(request.body.read, symbolize_names: true)
  logger.info "Initializing OAuth dance, received payload: #{params}"

  oauth_data = params.merge(
    {
      authorization_uri: Sharepoint::Authorization.authorization_url,
      token_credential_uri: Sharepoint::Authorization.token_credential_uri,
      scope: Sharepoint::Authorization.oauth_scope,
      state: JSON.dump(params[:state]),
      additional_parameters: { prompt: 'consent' }
    }
  )
  client = Signet::OAuth2::Client.new(oauth_data)
  { oauth2redirect: client.authorization_uri.to_s }.to_json
end

post '/oauth2/exchange' do
  content_type :json
  params = JSON.parse(request.body.read, symbolize_names: true)
  logger.info "Exchanging code for tokens, received payload: #{params}"
  oauth_data = {
    token_credential_uri: Sharepoint::Authorization.token_credential_uri,
    client_id: params[:client_id],
    client_secret: params[:client_secret]
  }
  # on the first dance
  oauth_data[:code] = params[:code] if params[:code].present?
  oauth_data[:redirect_uri] = params[:redirect_uri] if params[:redirect_uri].present?
  oauth_data[:session_state] = params[:session_state] if params[:session_state].present?
  oauth_data[:state] = params[:state] if params[:state].present?

  # on refresh dance
  if params[:refresh_token].present?
    oauth_data[:refresh_token] = params[:refresh_token]
    oauth_data[:grant_type] = :authorization
  end
  client = Signet::OAuth2::Client.new(oauth_data)
  client.fetch_access_token.to_json
end
