#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'utility/sink'
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

      def initialize
        super()
      end

      def sync_content(connector)
        puts "connector is: #{connector}"
        @sink = Utility::Sink::ElasticSink.new(connector['_source']['index_name'])
        error = nil
        config = connector['_source']['configuration']

        hostname = config['mongodb_hostname']['value']
        database = config['mongodb_database']['value']

        custom_client = Connectors::MongoDB::CustomClient.new(hostname, database)

        custom_client.documents(:listingsAndReviews).each do |document|
          doc = document.with_indifferent_access
          doc[:id] = doc.delete('_id')
          @sink.ingest(doc)
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
