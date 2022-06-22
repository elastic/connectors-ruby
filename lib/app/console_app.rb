#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'connectors_sdk/gitlab/connector'

puts 'Hello Connectors 3.0!'
puts 'Please enter a command. Available options:'
puts '- sync - start synchronization'
puts '- status - check the status of a third-party service'

command = gets.chomp

if command.to_sym == :sync
  connector = ConnectorsSdk::GitLab::Connector.new
  connector.sync_content({})
else
  puts 'Sorry, this command is not yet implemented'
end
