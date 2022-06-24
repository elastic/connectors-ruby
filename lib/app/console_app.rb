#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/config'
require 'connectors/base/registry'

module App
  module ConsoleApp
    extend self

    def start_sync
      connector = select_connector

      puts 'Starting content sync...'
      connector.sync_content({})
    end

    def show_status
      connector = select_connector

      puts 'Checking status...'
      puts connector.source_status({})
      puts
    end

    def read_command
      puts 'Please enter a command. Available options:'
      puts '- sync - start synchronization'
      puts '- status - check the status of a third-party service'
      puts '- exit - end the program'
      puts
      gets.chomp.to_sym
    end

    def select_connector
      puts 'Registered connectors:'
      connectors = registry.registered_connectors
      connectors.each_with_index { |name, index| puts "#{index} - #{name}" }
      puts
      puts 'Please enter the number of the connector you want:'
      order = gets.chomp.to_i
      registry.connector(connectors[order])
    end

    def registry
      @registry = Connectors::Base::REGISTRY
    end

    puts 'Hello Connectors 3.0!'

    while true
      command = read_command
      if command == :sync
        self.start_sync
      elsif command == :status
        self.show_status
      elsif command == :exit
        puts('Kthxbye!... ¯\_(ツ)_/¯')
        exit(0)
      else
        puts 'Sorry, this command is not yet implemented'
        exit(0)
      end
    end
  end
end


