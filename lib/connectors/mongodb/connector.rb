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
    $gclient_cache = {}
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

        if $gclient_cache.key?(@host) 
          @client = $gclient_cache[@host]
        else
          @client = if @user.present? || @password.present?
                     Mongo::Client.new(
                       @host,
                       database: @database,
                       direct_connection: to_boolean(@direct_connection),
                       user: @user,
                       password: @password,
                       max_pool_size: 1,
                       monitoring: false
                     )
                   else
                     Mongo::Client.new(
                       @host,
                       database: @database,
                       direct_connection: to_boolean(@direct_connection),
                       max_pool_size: 1,
                       monitoring: false
                     )
                   end
          $gclient_cache[@host] = @client
        end

      end

      def yield_documents
        cursor = @client[@collection].find
        skip = 0

        while true
          found_count = 0
          view = cursor.skip(skip).limit(100)
          puts "COUNT IS #{view.count_documents}"
          view.each do |document|
            ser = serialize(document)
            puts ser['id']
            yield ser
            found_count += 1
          end

          puts "FOUND #{found_count}"
          break if found_count == 0

          skip+= 100
          puts "skipping #{skip}"
        end
      end

      private

      def do_health_check
        Utility::Logger.debug("Mongo at #{@host}/#{@database} looks healthy.")
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
