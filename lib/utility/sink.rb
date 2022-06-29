#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/es_client'
require 'active_support/json'
require 'active_support/core_ext/numeric/time'

module Utility
  module Sink
    extend self

    def print_delim
      puts '----------------------------------------------------'
    end

    def print_header(header)
      print_delim
      puts header
      print_delim
    end

    class ConsoleSink
      include Sink

      def ingest(document)
        #LOUD
        print_header "Got a single document:"
      end

      def flush(size: nil)
        #LOUD
        print_header "Flushing"
      end

      def ingest_multiple(documents)
        #LOUD
        print_header "Got multiple documents:"
        puts documents
      end

      def delete_multiple(ids)
        #LOUD
        print_header "Deleting some stuff too"
        puts ids
      end
    end

    class ElasticSink
      include Sink

      attr_accessor :index_name

      def initialize(flush_threshold = 50, flush_interval = 1.minutes)
        super()
        @client = Utility::EsClient
        @queue = []
        @flush_threshold = flush_threshold
        @flush_interval = flush_interval
        @last_flush = Time.now
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
          send_data(data_to_flush)
          @last_flush = Time.now
        end
      end

      def ingest_multiple(documents)
        documents.each { |doc| @queue << doc unless doc.blank? }
        flush if ready_to_flush?
      end

      def delete_multiple(ids)
        #LOUD
        print_header "Deleting some stuff too"
        puts ids
        print_delim
      end

      private

      def send_data(documents)
        return if documents.empty?

        bulk_request = documents.map do |document|
          { index: { _index: index_name, _id: document[:id], data: document } }
        end

        puts "Request: #{bulk_request.to_json}"
        @client.bulk(body: bulk_request)
        puts "SENT #{documents.size} documents to the index"
      end

      def ready_to_flush?
        @queue.size >= @flush_threshold || Time.now - @last_flush > @flush_interval
      end
    end
  end

  class CombinedSink
    include Sink

    def initialize(sinks = [])
      @sinks = sinks
    end

    def ingest(document)
      @sinks.each { |sink| sink.ingest(document) }
    end

    def flush(size: nil)
      @sinks.each { |sink| sink.flush(size: size) }
    end

    def ingest_multiple(documents)
      @sinks.each { |sink| sink.ingest_multiple(documents) }
    end

    def delete_multiple(ids)
      @sinks.each { |sink| sink.delete_multiple(ids) }
    end
  end
end
