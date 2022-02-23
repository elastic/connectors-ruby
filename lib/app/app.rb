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

  return { results: connector.get_document_batch(), cursor: nil }.to_json
end

post '/download' do
  file = File.join(__dir__, 'cat.jpg')
  send_file(file, type: 'image/jpeg', disposition: 'inline')
end

post '/oauth2/init' do
  content_type :json
  body = JSON.parse(request.body.read, symbolize_names: true)
  logger.info "Received client ID: #{body[:client_id]} and client secret: #{body[:client_secret]}"
  logger.info "Received redirect URL: #{params[:redirect_uri]}"

  client = Signet::OAuth2::Client.new(
    authorization_uri: Sharepoint::Authorization.authorization_url,
    token_credential_uri: Sharepoint::Authorization.token_credential_uri,
    scope: Sharepoint::Authorization.oauth_scope,
    client_id: body[:client_id],
    client_secret: body[:client_secret],
    redirect_uri: body[:redirect_uri],
    state: JSON.dump(body[:state]),
    additional_parameters: { prompt: 'consent' }
  )
  { oauth2redirect: client.authorization_uri.to_s }.to_json
end

post '/oauth2/exchange' do
  content_type :json
  params = JSON.parse(request.body.read, symbolize_names: true)
  oauth_params = params[:oauth_params]
  logger.info "Received payload: #{params}"
  # TODO: need to request the tokens with auth code
  client = Signet::OAuth2::Client.new(
    token_credential_uri: Sharepoint::Authorization.token_credential_uri,
    client_id: params[:client_id],
    client_secret: params[:client_secret],
    redirect_uri: params[:redirect_uri],
    session_state: oauth_params[:session_state],
    state: oauth_params[:state],
    code: oauth_params[:code]
  )
  client.fetch_access_token.to_json
end
