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

  config.schema do
    required(:version).value(:string)
    required(:repository).value(:string)
    required(:revision).value(:string)

    required(:worker).hash do
      required(:max_thread_count).value(:integer)
    end

    required(:log_level).value(:string)
  end
end

::Config.load_and_set_settings(CONFIG_FILE)

module ConnectorsApp
  DEFAULT_PASSWORD = 'changeme'

  Config = ::Settings
end
