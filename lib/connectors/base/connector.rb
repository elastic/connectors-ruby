#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/output_sink'
require 'utility/exception_tracking'
require 'app/config'

module Connectors
  module Base
    class Connector
      def self.display_name
        raise 'Not implemented for this connector'
      end

      def self.configurable_fields
        {}
      end

      def self.service_type
        raise 'Not implemented for this connector'
      end

      def initialize(local_configuration: {}, remote_configuration: {})
        @local_configuration = local_configuration || {} # configuration of connector from local file
        @remote_configuration = remote_configuration || {} # configuration of connector from configurable fields
      end

      def yield_documents; end

      def is_healthy?(params = {})
        do_health_check(params)

        true
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Connector for service #{self.class.service_type} failed the health check for 3rd-party service.")
        false
      end
    end
  end
end
