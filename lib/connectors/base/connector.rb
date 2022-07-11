#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'core/output_sink'
require 'utility/logger'

module Connectors
  module Base
    class Connector
      def self.display_name
        raise 'Not implemented for this connector'
      end

      def self.configurable_fields
        {}
      end

      def service_type
        self.class::SERVICE_TYPE
      end

      def yield_documents(connector_settings); end

      def source_status(params = {})
        health_check(params)
        { :status => 'OK', :statusCode => 200, :message => "Connected to #{self.class.display_name}" }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(custom_client_error) ? e.status_code : 500, :message => e.message }
      end
    end
  end
end
