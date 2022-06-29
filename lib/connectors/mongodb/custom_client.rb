# frozen_string_literal: true

require 'mongo'
require 'utility/logger'

Mongo::Logger.logger.level = Utility::Logger.logger.level

# Mongo backend
module Connectors
  module MongoDB
    class CustomClient
      def initialize(host, database)
        @client = Mongo::Client.new([host],
                                    :connect => :direct,
                                    :database => database)

        Utility::Logger.debug("Existing Databases #{@client.database_names}")
        Utility::Logger.debug('Existing Collections:')
        @client.collections.each { |coll| Utility::Logger.debug(coll.name) }
      end

      def documents(collection_name)
        collection = @client[collection_name]

        # XXX yield, pagination, bulk read?
        collection.find
      end

      def close
        @client.close
      end

      def change_stream
        @client[:listingsAndReviews].watch.to_enum
      end
    end
  end
end
