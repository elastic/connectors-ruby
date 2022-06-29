#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
#
require 'active_support/core_ext/hash'

module Framework
  class IncompatibleConfigurableFieldsError < StandardError
    def initialize(expected_fields, actual_fields)
      super("Connector expected configurable fields: #{expected_fields}, actual stored fields: #{actual_fields}")
    end
  end

  class ConnectorMetadata
    def initialize(connector, elasticsearch_response)
      # TODO: is it a good way to move ahead?
      @connector = connector
      @elasticsearch_response = elasticsearch_response.with_indifferent_access

      validate!
    end

    def [](index)
      @elasticsearch_response[:_source][index]
    end

    def configured_fields
      puts @elasticsearch_response[:_source] 
      @elasticsearch_response[:_source][:configured_fields]
    end

    private

    def validate!
      expected_fields = @connector.configurable_fields.keys
      actual_fields = configured_fields.keys
  
      raise IncompatibleConfigurableFieldsError.new(expected_fields, actual_fields) if expected_fields != actual_fields
    end
  end
end
