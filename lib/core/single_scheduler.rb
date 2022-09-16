#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/scheduler'
require 'core/connector_settings'
require 'utility/logger'
require 'utility/exception_tracking'

module Core
  class SingleScheduler < Core::Scheduler
    def initialize(connector_id, poll_interval, heartbeat_interval)
      super(poll_interval, heartbeat_interval)
      @connector_id = connector_id
    end

    def connector_settings
      connector_settings = Core::ConnectorSettings.fetch_by_id(@connector_id)
      [connector_settings]
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, "Could not retrieve the connector by id #{@connector_id} due to unexpected error.")
      []
    end
  end
end
