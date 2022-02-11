require_relative '../connectors-api/target/connectors-api-1.0.0-SNAPSHOT.jar'

require 'rack'
require './app'

run Sinatra::Application
