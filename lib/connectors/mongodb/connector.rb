#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'mongo'
require 'connectors/base/connector'

module Connectors
  module MongoDB
    class Connector < Connectors::Base::Connector
      SERVICE_TYPE = 'mongo'

      def self.display_name
        'MongoDB'
      end

      def self.configurable_fields
        {
           :host => {
             :label => 'MongoDB Server Hostname'
           },
           :database => {
             :label => 'MongoDB Database'
           },
           :collection => {
             :label => 'MongoDB Collection'
           }
        }
      end

      def health_check(_params)
        Connectors::MongoDB::CustomClient.new(hostname, database)
      end

      def yield_documents(connector)
        config = connector.configuration

        host = config[:host][:value]
        database = config[:database][:value]
        collection = config[:collection][:value]

        mongodb_client = create_client(host, database)

        mongodb_client[collection].find.each do |document|
          doc = document.with_indifferent_access
          transform!(doc)

          yield doc
        end
      end

      def create_client(host, database)
        client = Mongo::Client.new([host],
                                   :connect => :direct,
                                   :database => database)

        Utility::Logger.debug("Existing Databases #{client.database_names}")
        Utility::Logger.debug('Existing Collections:')

        client.collections.each { |coll| Utility::Logger.debug(coll.name) }

        client
      end

      def transform!(mongodb_document)
        mongodb_document[:id] = mongodb_document.delete(:_id)
      end
    end
  end
end
