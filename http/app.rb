# frozen_string_literal: true

require 'sinatra'
require 'json'
require_relative '../hello-world-connector/src/main/ruby/hello_world'


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

get '/documents' do
  content_type :json
  hello_world = HelloWorld.new
  return { results: hello_world.fetch_Documents(), cursor: nil }.to_json
end

post '/download' do
  file = File.join(__dir__, 'cat.jpg')
  send_file(file, type: 'image/jpeg', disposition: 'inline')
end
