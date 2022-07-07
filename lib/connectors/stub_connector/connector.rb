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
      SERVICE_TYPE = 'stub_connector'

      def display_name
        'Stub Connector'
      end

      def configurable_fields
        {
          'foo' => {
            'label' => 'Foo',
            'value' => nil
          }
        }
      end

      def health_check(_params)
        true
      end

      def yield_documents(_connector)
        data = { name: 'stub connector' }
        yield data
      end
    end
  end
end
