#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'core/filtering/validation_status'
require 'connectors/mongodb/mongo_rules_parser'
require 'connectors/mongodb/mongo_advanced_snippet_snake_case_transformer'
require 'connectors/mongodb/mongo_advanced_snippet_against_schema_validator'
require 'mongo'
require 'utility'

module Connectors
  module MongoDB
    class Connector < Connectors::Base::Connector

      ALLOWED_TOP_LEVEL_FILTER_KEYS = %w[find aggregate]

      PAGE_SIZE = 100

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

      def self.advanced_snippet_validator
        MongoAdvancedSnippetAgainstSchemaValidator
      end

      def self.filter_transformers
        {
          'advanced_snippet' => [MongoAdvancedSnippetSnakeCaseTransformer]
        }
      end

      def initialize(configuration: {}, job_description: nil)
        super

        @host = @configuration.dig(:host, :value)
        @database = @configuration.dig(:database, :value)
        @collection = @configuration.dig(:collection, :value)
        @user = @configuration.dig(:user, :value)
        @password = @configuration.dig(:password, :value)
        @direct_connection = @configuration.dig(:direct_connection, :value)
      end

      def yield_documents
        with_client do |client|
          # We do paging using skip().limit() here to make Ruby recycle the memory for each page pulled from the server after it's not needed any more.
          # This gives us more control on the usage of the memory (we can adjust PAGE_SIZE constant for that to decrease max memory consumption).
          # It's done due to the fact that usage of .find.each leads to memory leaks or overuse of memory - the whole result set seems to stay in memory
          # during the sync. Sometimes (not 100% sure) it even leads to a real leak, when the memory for these objects is never recycled.
          cursor, options = create_db_cursor_on_collection(client[@collection])
          skip = 0

          found_overall = 0

          # if no overall limit is specified by filtering use -1 to not break ingestion, when no overall limit is specified (found_overall is only increased,
          # thus can never reach -1)
          overall_limit = Float::INFINITY

          if options.present?
            # there could be a skip parameter defined for filtering
            skip = options.fetch(:skip, skip)
            # there could be a limit parameter defined for filtering -> used for an overall limit (not a page limit, which was introduced for memory optimization)
            overall_limit = options.fetch(:limit, overall_limit)
          end

          overall_limit_reached = false

          loop do
            found_in_page = 0

            Utility::Logger.info("Requesting #{PAGE_SIZE} documents from MongoDB (Starting at #{skip})")
            view = cursor.skip(skip).limit(PAGE_SIZE)
            view.each do |document|
              yield_with_handling_tolerable_errors do
                yield serialize(document)
                found_in_page += 1
                found_overall += 1
                overall_limit_reached = found_overall >= overall_limit && overall_limit != Float::INFINITY
              end
              break if overall_limit_reached
            end

            page_was_empty = found_in_page == 0

            break if page_was_empty || overall_limit_reached

            skip += PAGE_SIZE
          end
        end
      end

      private

      def create_db_cursor_on_collection(collection)
        return create_find_cursor(collection) if @advanced_filter_config[:find].present?

        return create_aggregate_cursor(collection) if @advanced_filter_config[:aggregate].present?

        return create_simple_rules_cursor(collection) if @rules.present?

        collection.find
      end

      def create_aggregate_cursor(collection)
        aggregate = @advanced_filter_config[:aggregate]

        pipeline = aggregate[:pipeline]
        options = extract_options(aggregate)

        if !pipeline.nil? && pipeline.empty? && !options.present?
          Utility::Logger.warn('\'Aggregate\' was specified with an empty pipeline and empty options.')
        end

        [collection.aggregate(pipeline, options), options]
      end

      def create_find_cursor(collection)
        find = @advanced_filter_config[:find]

        filter = find[:filter]
        options = extract_options(find)

        if !filter.nil? && filter.empty? && !options.present?
          Utility::Logger.warn('\'Find\' was specified with an empty filter and empty options.')
        end

        [collection.find(filter, options), options]
      end

      def create_simple_rules_cursor(collection)
        filter = {}
        if @rules.present?
          parser = MongoRulesParser.new(@rules)
          filter = parser.parse
        end
        Utility::Logger.info("Filtering with simple rules filter: #{filter}")
        filter.present? ? collection.find(filter) : collection.find
      end

      def extract_options(mongodb_function)
        mongodb_function[:options].present? ? mongodb_function[:options] : {}
      end

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
