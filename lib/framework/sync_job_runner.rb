#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'concurrent'
require 'cron_parser'
require 'connectors/registry'

module Framework
  class IncompatibleConfigurableFieldsError < StandardError
    def initialize(expected_fields, actual_fields)
      super("Connector expected configurable fields: #{expected_fields}, actual stored fields: #{actual_fields}")
    end
  end

  class SyncJobRunner
    def initialize(connector_settings)
      @connector_settings = connector_settings
      @connector_instance = Connectors::REGISTRY.connector_class(@connector_settings.service_type).new
    end

    def execute
      validate_configuration!

      return unless should_sync?

      Utility::Logger.info("Starting to sync for connector #{@connector_settings['_id']}")
      ElasticConnectorActions.claim_job(@connector_settings.id)

      @connector_instance.sync_content(@connector_settings) do |error|
        ElasticConnectorActions.complete_sync(@connector_settings.id, error)
      end
    end

    private

    def validate_configuration!
      return unless @connector_settings.configuration_initialized?

      expected_fields = @connector_instance.configurable_fields.keys
      actual_fields = @connector_settings.configuration.keys

      raise IncompatibleConfigurableFieldsError.new(expected_fields, actual_fields) if expected_fields != actual_fields
    end

    def cron_parser(cronline)
      CronParser.new(cronline)
    rescue ArgumentError => e
      Utility::Logger.error("Fail to parse cronline #{cronline}. Error: #{e.message}")
      nil
    end

    def should_sync?
      return false unless @connector_settings.scheduling_settings[:enabled]
      return true if @connector_settings[:sync_now]

      last_synced = @connector_settings.scheduling_settings[:last_synced]
      return true if last_synced.nil? || last_synced.empty? # first run

      last_synced = Time.parse(last_synced) # TODO: unhandled exception
      sync_interval = scheduling_settings['interval']
      cron_parser = cron_parser(sync_interval)
      cron_parser && cron_parser.next(last_synced) < Time.now
    end
  end
end
