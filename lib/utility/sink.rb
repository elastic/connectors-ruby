#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/json'
require 'active_support/core_ext/numeric/time'
require 'concurrent-ruby'
require 'utility/es_client'

module Utility
  class Batcher
    def initialize(sink, flush_threshold = 50)
      # threshold and size are the same now, but it's good to separate the concepts:
      # threshold is "when to start flushing", while "size" is the size of the batch
      # that will be sent to the sink
      @flush_threshold = flush_threshold
      @flush_size = flush_threshold
      @sink = sink
      @queue = []
    end

    def add(element)
      @queue << element

      flush if ready_to_flush?
    end

    def add_multiple(elements)
      elements.each do |element|
        @queue << element
      end

      flush if ready_to_flush?
    end

    def flush
      until @queue.empty?
        items_to_ingest = @queue.pop(@flush_size)
        @sink.ingest_multiple(items_to_ingest)
      end
    end

    private

    def ready_to_flush?
      @queue.size >= @flush_threshold
    end
  end

  module Sink
    class Base
      def with_batching(batch_size = 50)
        batcher = Utility::Batcher.new(self, batch_size)
        yield(batcher)
        batcher.flush
      end
    end

    class ConsoleSink < Sink::Base
      def ingest(_document)
        print_header 'Got a single document:'
      end

      def ingest_multiple(documents)
        print_header 'Got multiple documents:'
        puts documents
      end

      def delete_multiple(ids)
        print_header 'Deleting some stuff too'
        puts ids
      end

      private

      def print_delim
        puts '----------------------------------------------------'
      end

      def print_header(header)
        print_delim
        puts header
        print_delim
      end
    end

    class ElasticSink < Sink::Base
      class IndexingFailedError < StandardError; end

      attr_accessor :index_name

      def initialize(index_name, flush_threshold = 50)
        @client = Utility::EsClient.new
        @queue = []
        @flush_threshold = flush_threshold
        @index_name = index_name
      end

      def ingest(document)
        ingest_multiple([document])
      end

      def ingest_multiple(documents)
        return if documents.empty?

        bulk_request = documents.map do |document|
          { index: { _index: index_name, _id: document[:id], data: document } }
        end

        response = @client.bulk(body: bulk_request)

        if response['errors']
          first_error = response['items'][0]
          raise IndexingFailedError.new("Failed to index documents into Elasticsearch.\nFirst error in response is: #{first_error.to_json}")
        end
      end

      def delete_multiple(_ids)
        raise 'not yet implemented'
      end
    end

    class CombinedSink < Sink::Base
      def initialize(sinks = [])
        @sinks = sinks
      end

      def ingest(document)
        @sinks.each { |sink| sink.ingest(document) }
      end

      def ingest_multiple(documents)
        @sinks.each { |sink| sink.ingest_multiple(documents) }
      end

      def delete_multiple(ids)
        @sinks.each { |sink| sink.delete_multiple(ids) }
      end
    end
  end
end
