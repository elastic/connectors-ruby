#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/scheduler'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'utility/logger'
require 'utility/exception_tracking'

module Core
  class NativeScheduler < Core::Scheduler
    def connector_settings
      Core::ConnectorSettings.fetch_native_connectors || []
    rescue *Utility::AUTHORIZATION_ERRORS => e
      # should be handled by the general scheduler
      raise e
    rescue StandardError => e
      Utility::ExceptionTracking.log_exception(e, 'Could not retrieve native connectors due to unexpected error.')
      []
    end
  end
end
