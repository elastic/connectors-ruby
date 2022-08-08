#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'yaml'
require 'elasticsearch'

LIB_DIR = File.expand_path("#{File.dirname(__FILE__)}/../lib")

def es_client
  Elasticsearch::Client.new(
    host: 'http://localhost:9200',
    user: 'elastic',
    password: 'changeme',
  )
end

def start_stack
  # starts Mongo and Elasticsearch, adds data in Mongo
  Dir.chdir(__dir__) {
    puts('Start the stack')
    system('make stop-stack')
    system('make run-stack')
    puts('Load mongo data')
    system('make load-data')
  }
  puts('Wait for all kids to be up') # can do better (ping in a loop)
  sleep 60
end

def stop_stack
  wipe_es
  Dir.chdir(__dir__) {
    puts('Stopping the stack')
    system('make stop-stack')
  }
end

def wipe_es
  puts('Wipe existing data')
  ['mongo', '.elastic-connectors', '.elastic-connectors-sync-jobs'].each do |i|
    es_client.indices.delete(index: i, ignore: [400, 404])
  end
end

def set_auth
  config_file = File.expand_path("#{File.dirname(__FILE__)}/../config/connectors.yml")

  body = {
    "name": 'mongo-connector',
    "role_descriptors": {
      "mongo-connector-role": {
        "cluster": ['all'],
        "index": [
          {
            "names": ['*'],
            "privileges": ['all']
          }
        ]
      }
    }
  }
  response = es_client.perform_request('POST', '_security/api_key',
                                       {}, body)

  api_key = response.body['encoded']
  # copy it into the config
  config = YAML.load_file(config_file)
  config['elasticsearch']['api_key'] = api_key.strip
  File.open(config_file, 'w') { |file| file.write(config.to_yaml) }
end

def run_sync
  # late import because the lib import the config when loaded
  # and we change it in `set_auth`
  $LOAD_PATH << LIB_DIR

  Dir["#{LIB_DIR}/**/*.rb"].sort.each { |f|
    next if f.include?('lib/app')

    absolute_dir = File.dirname(f)
    relative_dir = absolute_dir.sub("#{LIB_DIR}/", '')
    name = File.basename(f, '.rb')
    f = File.join(relative_dir, name)
    require(f)
  }

  require 'active_support/json'
  require 'core/elastic_connector_actions'
  require 'core/connector_settings'

  puts('Create the connector')
  Core::ElasticConnectorActions.ensure_connectors_index_exists
  Core::ElasticConnectorActions.ensure_job_index_exists
  connector_id = Core::ElasticConnectorActions.create_connector('mongo', 'mongo')

  config = {
    :host => {
      :value => '127.0.0.1:27018'
    },
    :database => {
      :value => 'sample_airbnb'
    },
    :collection => {
      :value => 'listingsAndReviews'
    }
  }

  Core::ElasticConnectorActions.update_connector_configuration(connector_id, config)
  Core::ElasticConnectorActions.update_connector_status(connector_id, 'configured')
  puts("Connector id #{connector_id}")
  puts('Syncing')

  config_settings = Core::ConnectorSettings.fetch(connector_id)

  # Creating the mapping for the index
  settings = Utility::Elasticsearch::Index::TextAnalysisSettings.new(:language_code => 'en', :analysis_icu => false).to_h
  mappings = Utility::Elasticsearch::Index::Mappings.default_text_fields_mappings(:connectors_index => true)
  body_payload = { settings: settings, mappings: mappings }
  Core::ElasticConnectorActions.ensure_index_exists(config_settings[:index_name], body_payload)

  Core::ElasticConnectorActions.force_sync(config_settings.id)
  Core::SyncJobRunner.new(config_settings, App::Config[:service_type]).execute

  puts('Sync done.')
end

def verify
  puts('Verifying data now')
  count = es_client.count(index: 'mongo').body['count']
  raise StandardError.new "Bad Count #{count}" unless count > 5000
  puts('Verified!')
end

if __FILE__ == $PROGRAM_NAME
  start_stack
  begin
    wipe_es
    set_auth
    run_sync
    verify
  ensure
    stop_stack
  end
end
