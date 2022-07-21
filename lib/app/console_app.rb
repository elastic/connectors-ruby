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
require 'app/worker'
require 'utility/logger'
require 'core/elastic_connector_actions'
require 'core/connector_settings'
require 'cron_parser'

module App
  ENV['TZ'] = 'UTC'
  Utility::Logger.level = App::Config['log_level']

  module ConsoleApp
    extend self

    INDEX_NAME_REGEXP = /[a-zA-Z]+[\d_\-a-zA-Z]*/

    @commands = [
      { :command => :sync_now, :hint => 'start one-time synchronization NOW' },
      { :command => :register, :hint => 'register connector with Elasticsearch' },
      { :command => :scheduling_on, :hint => 'enable connector scheduling' },
      { :command => :scheduling_off, :hint => 'disable connector scheduling' },
      { :command => :set_configurable_field, :hint => 'update the values of configurable fields' },
      { :command => :read_configurable_fields, :hint => 'read the stored values of configurable fields' },
      { :command => :status, :hint => 'check the status of a third-party service' },
      { :command => :exit, :hint => 'end the program' }
    ]

    def start_sync_now
      return unless connector_registered?
      puts 'Initiating synchronization NOW...'
      connector_id = App::Config[:connector_package_id]
      Core::ElasticConnectorActions.force_sync(connector_id)

      Core::ElasticConnectorActions.ensure_connectors_index_exists
      config_settings = Core::ConnectorSettings.fetch(connector_id)
      Core::ElasticConnectorActions.ensure_content_index_exists(
        config_settings[:index_name],
        App::Config[:use_analysis_icu],
        App::Config[:content_language_code]
      )
      Core::SyncJobRunner.new(config_settings, App::Config[:service_type]).execute
    end

    def show_status
      return unless connector_registered?
      connector = current_connector

      puts 'Checking status...'
      puts connector.source_status
      puts
    end

    def register_connector
      id = App::Config['connector_package_id']
      if id.present?
        puts "You already have registered a connector with ID: #{id}. Registering a new connector will overwrite the existing one."
        puts 'Are you sure you want to continue? (y/n)'
        return false unless gets.chomp.strip.casecmp('y').zero?
      end
      puts 'Please enter index name for data ingestion. Use only letters, underscored and dashes.'
      index_name = gets.chomp.strip
      unless INDEX_NAME_REGEXP.match?(index_name)
        puts "Index name #{index_name} contains symbols that aren't allowed!"
        return false
      end
      # these might not have been created without kibana
      Core::ElasticConnectorActions.ensure_connectors_index_exists
      # create the connector
      created_id = create_connector(index_name, force: true)
      App::Config[:connector_package_id] = created_id
      true
    end

    def validate_cronline(cronline)
      CronParser.new(cronline)
      true
    rescue ArgumentError
      false
    end

    def enable_scheduling
      return unless connector_registered?
      id = App::Config['connector_package_id']

      previous_schedule = Core::ConnectorSettings.fetch(id)&.scheduling_settings&.fetch(:interval, nil)
      if previous_schedule.present?
        puts "Please enter a valid crontab expression for scheduling. Previous schedule was: #{previous_schedule}."
      else
        puts 'Please enter a valid crontab expression for scheduling.'
      end
      cron_expression = gets.chomp.strip.downcase
      unless validate_cronline(cron_expression)
        puts "Cron expression #{cron_expression} isn't valid!"
        return
      end
      Core::ElasticConnectorActions.enable_connector_scheduling(id, cron_expression)
    end

    def disable_scheduling
      return unless connector_registered?
      id = App::Config['connector_package_id']
      puts "Are you sure you want to disable scheduling for connector #{id}? (y/n)"
      return unless gets.chomp.strip.casecmp('y').zero?
      Core::ElasticConnectorActions.disable_connector_scheduling(id)
    end

    def connector_registered?(warn_if_not: true)
      result = App::Config['connector_package_id'].present?
      if warn_if_not && !result
        'You have no connector ID yet. Register a new connector before continuing.'
      end
      result
    end

    def create_connector(index_name, force: false)
      connector_settings = Core::ConnectorSettings.fetch(App::Config['connector_package_id'])

      if connector_settings.nil? || force
        created_id = Core::ElasticConnectorActions.create_connector(index_name, App::Config['service_type'])
        connector_settings = Core::ConnectorSettings.fetch(created_id)
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

    def current_connector
      connector_settings = Core::ConnectorSettings.fetch(App::Config['connector_package_id'])
      service_type = App::Config['service_type']
      if service_type.present?
        return registry.connector(service_type, connector_settings.configuration)
      end
      puts 'You have not set connector service type in settings. Please do so before continuing.'
      nil
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

    def set_configurable_field
      return unless connector_registered?
      id = App::Config['connector_package_id']

      connector = current_connector
      connector_class = connector.class
      current_values = Core::ConnectorSettings.fetch(id)&.configuration
      return unless connector.present?

      puts 'Provided configurable fields:'
      configurable_fields = connector_class.configurable_fields
      fields = configurable_fields.each_key.map do |key|
        field = configurable_fields[key].with_indifferent_access
        current_value = current_values&.fetch(key, nil)
        { :command => key, :hint => "#{field[:label]} (current value: #{current_value}, default: #{field[:value]})" }
      end

      menu = App::Menu.new('Please select the configurable field:', fields)
      field_name = menu.select_command
      field_label = configurable_fields.dig(field_name, :label)

      puts 'Please enter the new value:'
      new_value = gets.chomp.strip
      Core::ElasticConnectorActions.set_configurable_field(id, field_name, field_label, new_value)
    end

    def read_configurable_fields
      return unless connector_registered?
      id = App::Config['connector_package_id']

      connector = current_connector
      connector_class = connector.class

      current_values = Core::ConnectorSettings.fetch(id)&.configuration
      return unless connector.present?

      puts 'Persisted values of configurable fields:'
      connector_class.configurable_fields.each_key.each do |key|
        field = connector_class.configurable_fields[key].with_indifferent_access
        current_value = current_values&.fetch(key, nil)
        puts "* #{field[:label]} - current value: #{current_value}, default: #{field[:value]}"
      end
    end

    loop do
      command = read_command
      case command
      when :sync_now
        start_sync_now
        wait_for_keypress('Synchronization finished!')
      when :status
        show_status
        wait_for_keypress('Status checked!')
      when :register
        if register_connector
          wait_for_keypress('Please store connector ID in config file and restart the program.')
        else
          wait_for_keypress('Registration canceled!')
        end
      when :scheduling_on
        enable_scheduling
        wait_for_keypress('Scheduling enabled! Start synchronization to see it in action.')
      when :scheduling_off
        disable_scheduling
        wait_for_keypress('Scheduling disabled! Starting synchronization will have no effect now.')
      when :set_configurable_field
        set_configurable_field
        wait_for_keypress('Configurable field is updated!')
      when :read_configurable_fields
        read_configurable_fields
        wait_for_keypress
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
