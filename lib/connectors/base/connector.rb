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

      def source_status(params = {})
        health_check(params)
        { :status => 'OK', :statusCode => 200, :message => "Connected to #{self.class.display_name}" }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => 500, :message => e.message }
      end
    end
  end
end
