#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'yaml'

module Connectors
  # We look for places in this order:
  # - CONNECTORS_CONFIG environement variable
  # - here/../config/connectors.yml
  CONFIG_FILE = ENV['CONNECTORS_CONFIG'] || File.join(__dir__, '..', 'config', 'connectors.yml')

  Config = YAML.load_file(CONFIG_FILE)
end
