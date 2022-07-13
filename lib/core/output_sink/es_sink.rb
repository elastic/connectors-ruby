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
  class EsSink < Core::OutputSink::BaseSink
    attr_accessor :index_name

    def initialize(index_name, flush_threshold = 50, flush_interval = 10.seconds)
      super()
      @client = Utility::EsClient.new
      @index_name = index_name
      @operation_queue = []
      @flush_threshold = flush_threshold
      @last_flush = Time.now
      @flush_task = Concurrent::TimerTask.new(execution_interval: flush_interval) do
        flush(:size => @operation_queue.size, :force => true)
      end
      @flush_task.execute
    end

    def ingest(document)
      return if document.blank?

      @operation_queue << { :index => { :_index => index_name, :_id => document[:id], :data => document } }
      flush if ready_to_flush?
    end

    def delete(doc_id)
      return if doc_id.nil?

      @operation_queue << { :delete => { :_index => index_name, :_id => doc_id } }
      flush if ready_to_flush?
    end

    def flush(size: nil, force: false)
      flush_size = size || @flush_threshold
      if force || ready_to_flush?
        data_to_flush = @operation_queue.pop(flush_size)
        send_data(data_to_flush)
      end
    end

    def ingest_multiple(documents)
      Utility::Logger.info "Enqueueing #{documents&.size} documents to the index #{index_name}"
      documents.each { |doc| ingest(doc) }
    end

    def delete_multiple(ids)
      Utility::Logger.info "Enqueueing #{ids&.size} ids to delete from the index #{index_name}"
      ids.each { |id| delete(id) }
    end

    private

    def send_data(ops)
      return if ops.empty?

      @client.bulk(:body => ops)
      Utility::Logger.info "Sent #{ops.size} operations to the index #{index_name}"
    end

    def ready_to_flush?
      @operation_queue.size >= @flush_threshold
    end
  end
end
