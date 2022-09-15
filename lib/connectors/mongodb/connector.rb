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
            transform!(doc)

            yield doc
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

      def transform!(mongodb_document)
        mongodb_document[:id] = mongodb_document.delete(:_id)
      end
    end
  end
end
