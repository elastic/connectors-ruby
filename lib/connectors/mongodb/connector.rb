#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'utility'

module Connectors
  module MongoDB
    class Connector < Connectors::Base::Connector
      SERVICE_TYPE = 'mongodb'

      def display_name
        'MongoDB'
      end

      def configurable_fields
        [
          {
            'key' => 'mongodb_hostname',
            'label' => 'MongoDB server hostname'
          },
          {
            'key' => 'mongodb_database',
            'label' => 'MongoDB Database'
          }
        ]
      end

      def health_check(_params)
        true
      end

      def sync(connector)
        puts "connector is: #{connector}"
        error = nil
        custom_client = Connectors::MongoDB::CustomClient.new('127.0.0.1:27021', 'sample_airbnb')

        documents = custom_client.documents(:listingsAndReviews).to_a

        puts "Found #{documents.size} documents!"

        batch = documents.shift(50)

        while batch && batch.size > 0
          bulk_requests = []
          
          batch.each do |doc|
            bulk_requests << { index: { _index: connector['_source']['index_name'] } }
            bulk_requests << { _id: doc[:id], data: doc }
          end

          Utility::EsClient.bulk(:body => bulk_requests)

          batch = documents.shift(50)
        end
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, "Failed to sync #{display_name}")
        error = e.message
      ensure
        yield error
      end
    end
  end
end
