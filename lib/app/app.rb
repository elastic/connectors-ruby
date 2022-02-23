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
  return { oauth2redirect: 'https://accounts.google.com/o/oauth2/auth' }.to_json
end
