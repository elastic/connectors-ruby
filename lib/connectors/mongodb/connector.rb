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
        'mongodb'
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

        @host = remote_configuration.dig(:host, :value)
        @database = remote_configuration.dig(:database, :value)
        @collection = remote_configuration.dig(:collection, :value)
        @user = remote_configuration.dig(:user, :value)
        @password = remote_configuration.dig(:password, :value)

        @direct_connection = local_configuration.present? && !!local_configuration[:direct_connection]
      end

      def yield_documents
        with_client do |client|
          client[@collection].find.each do |document|
            doc = document.with_indifferent_access

            yield serialize(doc)
          end
        end
      end

      private

      def do_health_check
        with_client do |_client|
          Utility::Logger.debug("Mongo at #{@host}/#{@database} looks healthy.")
        end
      end

      def with_client
        client = if @user.present? || @password.present?
                   Mongo::Client.new(
                     @host,
                     database: @database,
                     direct_connection: @direct_connection,
                     user: @user,
                     password: @password
                   )
                 else
                   Mongo::Client.new(
                     @host,
                     database: @database,
                     direct_connection: @direct_connection
                   )
                 end

        begin
          Utility::Logger.debug("Existing Databases #{client.database_names}")
          Utility::Logger.debug('Existing Collections:')

          client.collections.each { |coll| Utility::Logger.debug(coll.name) }

          yield client
        ensure
          client.close
        end
      end

      def serialize(mongodb_document)
        # This is some lazy serialization here.
        # Problem: MongoDB has its own format of things - e.g. ids are Bson::ObjectId, which when serialized to JSON
        # will produce something like: 'id': { '$oid': '536268a06d2d7019ba000000' }, which is not good for us

        mongodb_document.map do |key, value|
          remapped_key = key == '_id' ? 'id' : key

          remapped_value = case value
                           when BSON::ObjectId
                             value.to_s
                             break
                           when BSON::Decimal128
                             value.to_big_decimal # potential problems with NaNs but also will get treated as a string by Elasticsearch anyway
                             break
                           when String
                             # it's here cause Strings are Arrays too :/
                             value.to_s
                             break
                           when Array
                             value.map { |v| serialize(v) }
                             break
                           when Hash
                             serialize(value)
                             break
                           else
                             value
                           end

          [remapped_key, remapped_value]
        end.to_h
      end
    end
  end
end
