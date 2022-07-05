#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/config'
require 'connectors/registry'
require 'app/menu'
require 'app/connector'
require 'utility/logger'
require 'framework/elastic_connector_actions'
require 'framework/connector_settings'

module App
  ENV['TZ'] = 'UTC'

  module ConsoleApp
    extend self

    INDEX_NAME_REGEXP = /[a-zA-Z]+[\d_\-a-zA-Z]*/

    @commands = [
      { :command => :sync, :hint => 'start synchronization' },
      { :command => :register, :hint => 'register connector with Elasticsearch' },
      { :command => :status, :hint => 'check the status of a third-party service' },
      { :command => :exit, :hint => 'end the program' }
    ]

    def start_sync
      puts 'Initiating synchronization...'
      # these might not have been created without kibana
      connector_id = App::Config[:connector_package_id]
      config_settings = Framework::ConnectorSettings.fetch(connector_id)
      Framework::ElasticConnectorActions.ensure_index_exists(config_settings[:index_name])
      Framework::ElasticConnectorActions.force_sync(connector_id)
      App::Connector.start!
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
        puts "You already have registered a connector with ID: #{id}. Registering a new connector will overwrite the existing one."
        puts 'Are you sure you want to continue? (y/n)'
        return false unless gets.chomp.casecmp('y')&.zero?
      end
      puts 'Please enter index name for data ingestion. Use only letters, underscored and dashes.'
      index_name = gets.chomp.strip
      unless INDEX_NAME_REGEXP.match?(index_name)
        puts "Index name #{index_name} contains symbols that aren't allowed!"
        return false
      end
      # these might not have been created without kibana
      Framework::ElasticConnectorActions.ensure_connectors_index_exists
      # create the connector
      created_id = create_connector(index_name, force: true)
      App::Config[:connector_package_id] = created_id
      true
    end

    def create_connector(index_name, force: false)
      connector_settings = Framework::ConnectorSettings.fetch(App::Config['connector_package_id'])

      if connector_settings.nil? || force
        created_id = Framework::ElasticConnectorActions.create_connector(index_name, App::Config['service_type'])
        connector_settings = Framework::ConnectorSettings.fetch(created_id)
      end

      connector_settings.id
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

    def select_connector
      puts 'Provided connectors:'

      menu = App::Menu.new('Please select the connector:', registry.registered_connectors)
      connector_name = menu.select_command

      registry.connector(connector_name)
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
      when :status
        show_status
        wait_for_keypress('Status checked!')
      when :register
        if register_connector
          wait_for_keypress('Please store connector ID in config file and restart the program.')
        else
          wait_for_keypress('Registration canceled!')
        end
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
    Utility::Logger.error_with_backtrace(exception: e)
    exit(false)
  end
end
