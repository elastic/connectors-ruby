#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'config'
require 'utility'

# We look for places in this order:
# - CONNECTORS_CONFIG environment variable
# - here: /../../config/connectors.yml
CONFIG_FILE = ENV['CONNECTORS_CONFIG'] || File.join(__dir__, '../..', 'config', 'connectors.yml')

puts "Parsing #{CONFIG_FILE} configuration file."

::Config.setup do |config|
  config.evaluate_erb_in_yaml = false
  config.use_env = true
  config.env_prefix = ''

  config.schema do
    required(:version).value(:string)
    required(:repository).value(:string)
    required(:revision).value(:string)

    required(:elasticsearch).hash do
      optional(:cloud_id).value(:string)
      optional(:hosts).value(:string)
      required(:api_key).value(:string)
    end

    required(:connector_id).value(:string)
    required(:service_type).value(:string)
    required(:log_level).value(:string)

    optional(:idle_timeout).value(:integer)

    optional(:gitlab).hash do
      required(:api_token).value(:string)
    end
  end
end

::Config.load_and_set_settings(CONFIG_FILE)

module App
  DEFAULT_PASSWORD = 'changeme'

  # If it's on cloud (i.e. EnvVar ENT_SEARCH_CONFIG_PATH is set), elasticsearch config in ent-search will be used.
  def self.ent_search_es_config
    ent_search_config_path = ENV['ENT_SEARCH_CONFIG_PATH']
    unless ent_search_config_path
      Utility::Logger.info('ENT_SEARCH_CONFIG_PATH is not found, use connector service config.')
      return nil
    end

    Utility::Logger.info("Found ENT_SEARCH_CONFIG_PATH, loading ent-search config from #{ent_search_config_path}")
    ent_search_config = begin
      YAML.load_file(ent_search_config_path)
    rescue StandardError => e
      Utility::Logger.error("Failed to load ent-search config #{ent_search_config_path}: #{e.message}")
      return nil
    end

    unless ent_search_config.is_a?(Hash)
      Utility::Logger.error("Invalid ent-search config: #{ent_search_config.inspect}")
      return nil
    end

    host = ent_search_config['elasticsearch.host'] || ent_search_config.dig('elasticsearch', 'host')
    username = ent_search_config['elasticsearch.username'] || ent_search_config.dig('elasticsearch', 'username')
    password = ent_search_config['elasticsearch.password'] || ent_search_config.dig('elasticsearch', 'password')

    missing_fields = []
    missing_fields << 'elasticsearch.host' unless host
    missing_fields << 'elasticsearch.username' unless username
    missing_fields << 'elasticsearch.password' unless password
    if missing_fields.any?
      Utility::Logger.error("Incomplete elasticsearch config, missing #{missing_fields.join(', ')}")
      return nil
    end

    uri = begin
      URI.parse(host)
    rescue URI::InvalidURIError => e
      Utility::Logger.error("Failed to parse elasticsearch host #{host}: #{e.message}")
      return nil
    end

    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      Utility::Logger.error("Invalid elasticsearch host #{host}, it must be a http or https URI.")
      return nil
    end

    {
      :hosts => [
        {
          scheme: uri.scheme,
          user: username,
          password: password,
          host: uri.host,
          port: uri.port
        }
      ]
    }
  end

  Config = ::Settings.tap do |config|
    if ent_search_config = ent_search_es_config
      Utility::Logger.error('Overriding elasticsearch config with ent-search config')
      config[:elasticsearch] = ent_search_config
    end
  end
end
