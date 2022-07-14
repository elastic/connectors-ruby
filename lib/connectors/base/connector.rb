#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/output_sink'
require 'utility/logger'
require 'app/config'

module Connectors
  module Base
    class Connector
      def initialize(local_configuration = {})
        # connector-specific configuration that comes from the local yaml config file
        # should be stored under the section that has the same name as the connector service_type
        @local_configuration = local_configuration || {}
      end

      def yield_documents(connector_settings)
        ;
      end

      def source_status(params = {})
        health_check(params)
        { :status => 'OK', :statusCode => 200, :message => "Connected to #{display_name}" }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(custom_client_error) ? e.status_code : 500, :message => e.message }
      end

      def display_name
        raise 'Not implemented for this connector'
      end

      def service_type
        self.class::SERVICE_TYPE
      end

      def configurable_fields
        {}
      end
    end
  end
end
