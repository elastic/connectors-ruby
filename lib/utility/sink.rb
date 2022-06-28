#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'elasticsearch'
require 'active_support/json'

module Utility
  module Sink
    class ConsoleSink
      def ingest(document)
        #LOUD
        puts "=============================================================="
        puts "Got a single document:"
        puts document
        puts "=============================================================="
      end

      def flush(size: nil)
        #LOUD
        puts "=============================================================="
        puts "Flushing"
        puts "=============================================================="
      end

      def ingest_multiple(documents)
        #LOUD
        puts "=============================================================="
        puts "Got multiple documents:"
        puts documents
        puts "=============================================================="
      end

      def delete_multiple(ids)
        #LOUD
        puts "=============================================================="
        puts "Deleting some stuff too"
        puts ids
        puts "=============================================================="
      end
    end

    class FileSink
      DATA_FILES_PATH = '/tmp/data'.freeze

      def initialize
        Dir.mkdir(DATA_FILES_PATH) unless Dir.exist?(DATA_FILES_PATH)

        @path = DATA_FILES_PATH
      end

      def ingest(document)
        File.write("#{@path}/#{document[:id]}.data", document)
      end

      def flush(size: nil)
        # NO NEED TO FLUSH
        # MEH
      end

      def ingest_multiple(documents)
        documents.each do |doc|
          ingest(doc)
        end

        puts "Saved #{documents.count} files"
      end

      def delete_multiple(ids)
        puts "I'm just a file, I won't do it!"
        puts "Deleting ids: #{ids}"
      end
    end

    class ElasticSink
      attr_accessor :index_name

      def initialize
        @client = Elasticsearch::Client.new(
          user: 'elastic',
          password: 'changeme',
        )
        @queue = []
        @flush_threshold = 50
      end

      def ingest(document)
        return if document.blank?

        @queue << document

        flush if ready_to_flush?
      end

      def flush(size: nil)
        flush_size = size || @flush_threshold
        if ready_to_flush?
          data_to_flush = @queue.pop(flush_size)
          send(data_to_flush)
        end
      end

      def ingest_multiple(documents)
        documents.each { |doc| @queue << doc unless doc.blank? }

        flush if ready_to_flush?
      end

      def delete_multiple(ids)
        #LOUD
        puts "=============================================================="
        puts "Deleting some stuff too"
        puts ids
        puts "=============================================================="
      end

      private

      def send(documents)
        return if documents.empty?

        bulk_request = documents.map do |document|
          { index:  { _index: index_name, _id: document[:id], data: document } }
        end

        puts "Request: #{bulk_request.to_json}"
        @client.bulk(body: bulk_request)
        puts "SENT #{documents.size} documents to the index"
      end

      def ready_to_flush?
        @queue.size >= @flush_threshold
      end
    end
  end
end
