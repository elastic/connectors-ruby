#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'

module ConnectorsSdk
  module FakeConnector
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'fake_connector'

      def display_name
        'Fake Connector'
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

      def document_batch(_params)
        results = 30.times.map do |i|
          {
            :action => :create_or_update,
            :document => {
              :id => "document_#{i}",
              :type => 'document',
              :body => "contents for document number: #{i}"
            },
            :download => nil
          }
        end

        [results, {}, true]
      end

      def deleted(_params)
        []
      end

      def permissions(_params)
        []
      end
    end
  end
end
