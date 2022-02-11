# frozen_string_literal: true

require 'sinatra'
require 'json'


get '/' do
  content_type :json
  { version: '1.0' }.to_json
end

get '/status' do
  content_type :json
  { status: 'IDLING' }.to_json
end

get '/documents' do
  content_type :json
  cursor = params['cursor'] || {}
  { results => [] }.to_json
end

get '/file/:id' do |_id|
  file = File.join(__dir__, 'cat.jpg')
  send_file(file, type: 'image/jpeg', disposition: 'inline')
end
