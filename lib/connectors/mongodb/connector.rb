#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

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
             :label => 'Server Hostname'
           },
           :user => {
             :label => 'Username'
           },
           :password => {
             :label => 'Password'
           },
           :database => {
             :label => 'Database'
           },
           :collection => {
             :label => 'Collection'
           },
           :direct_connection => {
             :label => 'Direct connection? (true/false)'
           }
        }
      end

      def initialize(configuration: {})
        super

        @host = configuration.dig(:host, :value)
        @database = configuration.dig(:database, :value)
        @collection = configuration.dig(:collection, :value)
        @user = configuration.dig(:user, :value)
        @password = configuration.dig(:password, :value)
        @direct_connection = configuration.dig(:direct_connection, :value)
      end

      def yield_documents
        with_client do |client|
          client[@collection].find.each do |document|
            yield serialize(document)
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
        raise "Invalid value for 'Direct connection' : #{@direct_connection}." unless %w[true false].include?(@direct_connection.to_s.strip.downcase)

        args = {
                 database: @database,
                 direct_connection: to_boolean(@direct_connection)
               }

        if @user.present? || @password.present?
          args[:user] = @user
          args[:password] = @password
        end

        Mongo::Client.new(@host, args) do |client|
          databases = client.database_names

          Utility::Logger.debug("Existing Databases: #{databases}")
          check_database_exists!(databases, @database)

          collections = client.database.collection_names

          Utility::Logger.debug("Existing Collections: #{collections}")
          check_collection_exists!(collections, @database, @collection)

          yield client
        end
      end

      def check_database_exists!(databases, database)
        return if databases.include?(database)

        raise "Database (#{database}) does not exist. Existing databases: #{databases.join(', ')}"
      end

      def check_collection_exists!(collections, database, collection)
        return if collections.include?(collection)

        raise "Collection (#{collection}) does not exist within database '#{database}'. Existing collections: #{collections.join(', ')}"
      end

      def serialize(mongodb_document)
        # This is some lazy serialization here.
        # Problem: MongoDB has its own format of things - e.g. ids are Bson::ObjectId, which when serialized to JSON
        # will produce something like: 'id': { '$oid': '536268a06d2d7019ba000000' }, which is not good for us
        case mongodb_document
        when BSON::ObjectId
          mongodb_document.to_s
        when BSON::Decimal128
          mongodb_document.to_big_decimal # potential problems with NaNs but also will get treated as a string by Elasticsearch anyway
        when String
          # it's here cause Strings are Arrays too :/
          mongodb_document.to_s
        when Array
          mongodb_document.map { |v| serialize(v) }
        when Hash
          mongodb_document.map do |key, value|
            key = 'id' if key == '_id'
            remapped_value = serialize(value)
            [key, remapped_value]
          end.to_h
        else
          mongodb_document
        end
      end

      def to_boolean(value)
        value == true || value =~ (/(true|t|yes|y|1)$/i)
      end
    end
  end
end
