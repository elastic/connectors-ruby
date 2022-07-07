#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'concurrent-ruby'
require 'core/output_sink/base_sink'
require 'utility/es_client'
require 'utility/logger'

module Core::OutputSink
  class ElasticSink < Core::OutputSink::BaseSink
    attr_accessor :index_name

    def initialize(index_name, flush_threshold = 50, flush_interval = 10.seconds)
      super()
      @client = Utility::EsClient.new
      @index_name = index_name
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
        { :index => { :_index => index_name, :_id => document[:id], :data => document } }
      end
      @client.bulk(:body => bulk_request)
      Utility::Logger.info "SENT #{documents.size} documents to the index #{index_name}"
    rescue StandardError => e
      Utility::Logger.error_with_backtrace(
        message: "Failed to send data to the index #{index_name}: #{e.message}",
        exception: e
      )
    end

    def ready_to_flush?
      @queue.size >= @flush_threshold
    end
  end
end
