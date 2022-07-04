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
require 'utility/logger'

module Utility
  module Sink
    module_function

    def print_delim
      Utility::Logger.info '----------------------------------------------------'
    end

    def print_header(header)
      print_delim
      Utility::Logger.info header
      print_delim
    end

    class ConsoleSink
      include Sink

      def ingest(_document)
        print_header 'Got a single document:'
      end

      def flush(size: nil)
        print_header 'Flushing'
      end

      def ingest_multiple(documents)
        print_header 'Got multiple documents:'
        Utility::Logger.info documents
      end

      def delete_multiple(ids)
        print_header 'Deleting some stuff too'
        Utility::Logger.info ids
      end
    end

    class ElasticSink
      include Sink

      attr_accessor :index_name

      def initialize(_index_name, flush_threshold = 50, flush_interval = 10.seconds)
        super()
        @client = Utility::EsClient
        @index_name = _index_name
        @queue = []
        @flush_threshold = flush_threshold
        @last_flush = Time.now
        @flush_task = Concurrent::TimerTask.new(execution_interval: flush_interval) do
          flush(:size => @queue.size, :force => true)
        end
        @flush_task.execute
      end

      def ingest(document)
        return if document.blank?

        @queue << document

        flush if ready_to_flush?
      end

      def flush(size: nil, force: false)
        flush_size = size || @flush_threshold
        if force || ready_to_flush?
          data_to_flush = @queue.pop(flush_size)
          send_data(data_to_flush)
        end
      end

      def ingest_multiple(documents)
        documents.each { |doc| @queue << doc unless doc.blank? }
        flush if ready_to_flush?
      end

      def delete_multiple(ids)
        print_header 'Deleting some stuff too'
        Utility::Logger.info ids
        print_delim
      end

      private

      def send_data(documents)
        return if documents.empty?

        bulk_request = documents.map do |document|
          { index: { _index: index_name, _id: document[:id], data: document } }
        end

        Utility::Logger.info "Request: #{bulk_request.to_json}"
        @client.bulk(:index => index_name, :body => bulk_request)
        Utility::Logger.info "SENT #{documents.size} documents to the index #{index_name}"
      end

      def ready_to_flush?
        @queue.size >= @flush_threshold
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
end
