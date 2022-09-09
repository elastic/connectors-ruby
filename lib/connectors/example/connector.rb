#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'utility'

module Connectors
  module Example
    class Connector < Connectors::Base::Connector
      def self.service_type
        'example'
      end

      def self.display_name
        'Example Connector'
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

      def do_health_check(_params)
        # Do the health check by trying to access 3rd-party system just to verify that everything is set up properly.
        #
        # To emulate unhealthy 3rd-party system situation, uncomment the following line:
        # raise 'something went wrong'
      end

      def yield_documents
        data = { id: '123', name: 'example document' }
        yield data
      end
    end
  end
end
