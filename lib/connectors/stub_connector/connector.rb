#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'utility'

module Connectors
  module StubConnector
    class Connector < Connectors::Base::Connector
      def self.service_type
        'stub_connector'
      end

      def self.display_name
        'Stub Connector'
      end

      def self.configurable_fields
        {
          'foo' => {
            'label' => 'Foo',
            'value' => nil
          }
        }
      end

      def initialize(local_configuration: {}, remote_configuration: {})
        super
      end

      def health_check(_params)
        true
      end

      def yield_documents
        data = { id: '123', name: 'stub connector' }
        yield data
      end
    end
  end
end
