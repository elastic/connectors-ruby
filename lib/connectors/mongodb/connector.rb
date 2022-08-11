#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/base/connector'
require 'mongo'

module Connectors
  module MongoDB
    class Connector < Connectors::Base::Connector
      def self.service_type
        'mongo'
      end

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

      def initialize(local_configuration: {}, remote_configuration: {})
        super

        @host = remote_configuration.dig(:host, :value)
        @database = remote_configuration.dig(:database, :value)
        @collection = remote_configuration.dig(:collection, :value)
      end

      def yield_documents
        mongodb_client = create_client(@host, @database)

        mongodb_client[@collection].find.each do |document|
          doc = document.with_indifferent_access
          transform!(doc)

          yield doc
        end
      end

      private

      def health_check(_params)
        create_client(@host, @database)
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
