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
        [
          {
            'key' => 'third_party_url',
            'label' => 'Third Party URL'
          },
          {
            'key' => 'third_party_api_key',
            'label' => 'Third Party API Key'
          }
        ]
      end

      def health_check(_params)
        true
      end

      def sync(connector)
        error = nil
        body = [
          { index: { _index: connector['_source']['index_name'], _id: 1, data: { name: 'stub connector' } } }
        ]
        Utility::ElasticsearchClient.bulk(:body => body)
      rescue StandardError => e
        Utility.Logger.error("Error happened when syncing #{display_name}. Error: #{e.message}")
        error = e.message
      ensure
        yield error
      end
    end
  end
end
