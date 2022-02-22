# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'connectors/sharepoint/sharepoint'

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

post '/oauth/init' do
  content_type :json
  params = request.params
  logger.info "Received client ID: #{params[:client_id]} and client secret: #{params[:client_secret]}"
  logger.info "Received redirect URL: #{params[:redirect_uri]}"
  {
    oauth2redirect: Sharepoint::HttpCallWrapper.authorization_url
  }.to_json
end

post '/oauth/exchange' do
  content_type :json
  params = request.params
  logger.info "Received auth code: #{params[:authorization_code]}"
  logger.info "Received redirect URL: #{params[:redirect_uri]}"
  # TODO need to request the tokens with auth code
  { access_token: 'dummy_access_token', refresh_token: 'dummy_refresh_token' }.to_json
end
