#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'utility/logger'
require 'utility/exception_tracking'
require 'utility/error_monitor'

module Connectors
  class TolerableErrorHelper
    def initialize(error_monitor)
      @error_monitor = error_monitor
    end

    def yield_single_document(identifier: nil)
      Utility::Logger.debug("Extracting single document for #{identifier}") if identifier
      yield
      @error_monitor.note_success
    rescue *fatal_exception_classes => e
      Utility::ExceptionTracking.augment_exception(e)
      Utility::Logger.error("Encountered a fall-through error during extraction#{identifying_error_message(identifier)}: #{e.class}: #{e.message} {:message_id => #{e.id}}")
      raise
    rescue StandardError => e
      Utility::ExceptionTracking.augment_exception(e)
      Utility::Logger.warn("Encountered error during extraction#{identifying_error_message(identifier)}: #{e.class}: #{e.message} {:message_id => #{e.id}}")
      @error_monitor.note_error(e, :id => e.id)
    end

    private

    def identifying_error_message(identifier)
      identifier.present? ? " of '#{identifier}'" : ''
    end

    def fatal_exception_classes
      [
        Utility::ErrorMonitor::MonitoringError,
        Core::ConnectorNotFoundError,
        Core::ConnectorJobNotFoundError,
        Core::ConnectorJobCanceledError,
        Core::ConnectorJobNotRunningError
      ]
    end
  end
end
