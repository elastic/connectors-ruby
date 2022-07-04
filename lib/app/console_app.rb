#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/config'
require 'connectors/base/registry'
require 'app/menu'
require 'app/connector'

module App
  ENV['TZ'] = 'UTC'

  module ConsoleApp
    extend self

    INDEX_NAME_REGEXP = /[a-zA-Z]+[\d_\-a-zA-Z]*/

    @commands = [
      { :command => :register, :hint => 'register connector with Elasticsearch' },
      { :command => :sync, :hint => 'start synchronization' },
      { :command => :status, :hint => 'check the status of a third-party service' },
      { :command => :exit, :hint => 'end the program' }
    ]

    def start_sync
      puts 'Initiating synchronization...'
      App::Connector.initiate_sync
    end

    def show_status
      connector = select_connector

      puts 'Checking status...'
      puts connector.source_status
      puts
    end

    def register_connector
      id = App::Config['connector_package_id']
      if id.present?
        puts "You already have registered a connector with ID: #{id}. Registering a new connector will not use the existing one."
        puts 'Are you sure you want to continue? (y/n)'
        return unless gets.chomp.casecmp('y').zero?
      end
      puts 'Please enter index name for data ingestion. Use only letters, underscored and dashes.'
      index_name = gets.chomp.strip
      unless INDEX_NAME_REGEXP.match?(index_name)
        puts "Index name #{index_name} contains symbols that aren't allowed!"
        return
      end
      id = App::Connector.register_connector(index_name)
      App::Config[:connector_package_id] = id
      puts "Connector with ID #{id} registered successfully. Please store the ID in config file and restart the program."
    end

    def read_command
      menu = App::Menu.new('Please select the command:', @commands)
      menu.select_command
    rescue Interrupt
      exit_normally
    end

    def wait_for_keypress(message = nil)
      if message.present?
        puts message
      end
      puts 'Press any key to continue...'
      gets
    end

    def select_connector(params = {})
      puts 'Provided connectors:'

      menu = App::Menu.new('Please select the connector:', registry.registered_connectors)
      connector_name = menu.select_command

      registry.connector(connector_name, params)
    end

    def exit_normally(message = 'Kthxbye!... ¯\_(ツ)_/¯')
      puts(message)
      exit(true)
    end

    def registry
      @registry = Connectors::REGISTRY
    end

    puts 'Hello Connectors 3.0!'
    sleep(1)

    loop do
      command = read_command
      case command
      when :sync
        start_sync
        wait_for_keypress('Sync finished!')
      when :status
        show_status
        wait_for_keypress('Status checked!')
      when :register
        register_connector
        wait_for_keypress('Registered connector in Elasticsearch!')
      when :exit
        exit_normally
      else
        exit_normally('Sorry, this command is not yet implemented')
      end
    end
  rescue SystemExit
    puts 'Exiting.'
  rescue Interrupt
    exit_normally
  rescue StandardError => e
    puts e.message
    puts e.backtrace
    exit(false)
  end
end
