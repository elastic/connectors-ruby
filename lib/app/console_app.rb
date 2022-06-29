#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/config'
require 'connectors/base/registry'
require 'connectors/base/registry'
require 'app/menu'

module App
  module ConsoleApp
    extend self

    INDEX_NAME_REGEXP = /[a-zA-Z]+[\d_\-a-zA-Z]*/
    @commands = [
      { :command => :sync, :hint => 'start synchronization' },
      { :command => :status, :hint => 'check the status of a third-party service' },
      { :command => :exit, :hint => 'exit - end the program' }
    ]

    def start_sync
      puts 'Please enter index name for data ingestion. Use only letters, underscored and dashes.'
      index_name = gets.chomp.strip
      unless INDEX_NAME_REGEXP.match?(index_name)
        puts "Index name #{index_name} contains symbols that aren't allowed!"
        return
      end

      connector = select_connector({ :index_name => index_name })

      puts 'Starting content sync...'
      connector.sync_content
    end

    def show_status
      connector = select_connector

      puts 'Checking status...'
      puts connector.source_status
      puts
    end

    def read_command
      menu = App::Menu.new('Please select the command:', @commands)
      menu.select_command
    end

    def wait_for_keypress(message = nil)
      if message.present?
        puts message
      end
      puts 'Press any key to continue...'
      gets
    end

    def select_connector(params = {})
      puts 'Registered connectors:'

      menu = App::Menu.new('Please select the connector:', registry.registered_connectors)
      connector_name = menu.select_command

      registry.connector(connector_name, params)
    end

    def exit_normally(message = 'Kthxbye!... ¯\_(ツ)_/¯')
      puts(message)
      exit(true)
    end

    def registry
      @registry = Connectors::Base::REGISTRY
    end

    puts 'Hello Connectors 3.0!'
    sleep(1)

    while true
      command = read_command
      case command
      when :sync
        self.start_sync
        wait_for_keypress('Sync finished!')
      when :status
        self.show_status
        wait_for_keypress('Status checked!')
      when :exit
        self.exit_normally
      else
        self.exit_normally('Sorry, this command is not yet implemented')
      end
    end
  rescue SystemExit, Interrupt
    self.exit_normally
  rescue Exception => e
    puts e.message
    puts e.backtrace
    exit(false)
  end
end


