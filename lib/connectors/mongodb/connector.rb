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
           :user => {
             :label => 'MongoDB User'
           },
           :password => {
             :label => 'MongoDB Passwd'
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
        remote_configuration = remote_configuration.transform_keys(&:to_sym)

        @host = remote_configuration.dig(:host, :value)
        @database = remote_configuration.dig(:database, :value)
        @collection = remote_configuration.dig(:collection, :value)
        @user = remote_configuration.dig(:user, :value)
        @password = remote_configuration.dig(:password, :value)

        # XXX when yield_documents is called, we lost the values
        # hardcoding them for now
      end

      def yield_documents
        with_client(@host, @database) do |client|
          client[@collection].find.each do |document|
            doc = document.with_indifferent_access
            transform!(doc)
            yield doc
          end
        end
      end

      private

      def do_health_check
        with_client(@host, @database) do |_client|
          Utility::Logger.debug("Mongo at #{@host}/#{@database} looks healthy.")
        end
      end

      def with_client(host, database)
        client = Mongo::Client.new([host],
                                   :connect => :direct,
                                   :database => database)
        begin
          Utility::Logger.debug("Existing Databases #{client.database_names}")
          Utility::Logger.debug('Existing Collections:')

          client.collections.each { |coll| Utility::Logger.debug(coll.name) }
          yield client
        ensure
          client.close
        end
      end

      def transform!(mongodb_document)
        mongodb_document[:id] = mongodb_document.delete(:_id)
      end
    end
  end
end
