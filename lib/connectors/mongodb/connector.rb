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
      SERVICE_TYPE = 'mongo'

      def display_name
        'MongoDB'
      end

      def configurable_fields
        {
           'host' => {
             'label' => 'MongoDB Server Hostname'
           },
           'database' => {
             'label' => 'MongoDB Database'
           },
           'collection' => {
             'label' => 'MongoDB Collection'
           }
        }
      end

      def health_check(_params)
        Connectors::MongoDB::CustomClient.new(hostname, database)
      end

      def initialize
        super()
      end

      def sync_content(connector)
        puts "connector is: #{connector.to_json}"
        @sink = Utility::Sink::ElasticSink.new(connector['index_name'])

        config = connector.configuration

        hostname = config['host']['value']
        database = config['database']['value']
        collection = config['collection']['value']

        custom_client = Connectors::MongoDB::CustomClient.new(hostname, database)

        custom_client.documents(collection).each do |document|
          doc = document.with_indifferent_access
          @sink.ingest(doc)
        end
      end
    end


    def transform!(mongodb_document)
      mongodb_document[:id] = mongodb_document.delete('_id')
    end
  end
end
