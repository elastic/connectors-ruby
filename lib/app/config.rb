#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'config'

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

  Config = ::Settings
end
