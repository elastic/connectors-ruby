#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'app/config'
require 'core/output_sink/base_sink'
require 'utility/es_client'
require 'utility/logger'

module Core::OutputSink
  class EsSink < Core::OutputSink::BaseSink
    def initialize(index_name, request_pipeline, flush_threshold = 50)
      super()
      @client = Utility::EsClient.new(App::Config[:elasticsearch])
      @index_name = index_name
      @request_pipeline = request_pipeline
      @operation_queue = []
      @flush_threshold = flush_threshold
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

    def flush(size: nil)
      flush_size = size || @flush_threshold

      while @operation_queue.any?
        data_to_flush = @operation_queue.pop(flush_size)
        send_data(data_to_flush)
      end
    end

    def ingest_multiple(documents)
      Utility::Logger.debug "Enqueueing #{documents&.size} documents to the index #{index_name}."
      documents.each { |doc| ingest(doc) }
    end

    def delete_multiple(ids)
      Utility::Logger.debug "Enqueueing #{ids&.size} ids to delete from the index #{index_name}."
      ids.each { |id| delete(id) }
    end

    def ingestion_stats
      {
          :indexed_document_count => 0,
          :indexed_document_volume => 0,
          :deleted_document_count => 0
      }
    end

    private

    attr_accessor :index_name

    def send_data(ops)
      return if ops.empty?

      @client.bulk(:body => ops, :pipeline => @request_pipeline)
      Utility::Logger.info "Applied #{ops.size} upsert/delete operations to the index #{index_name}."
    end

    def ready_to_flush?
      @operation_queue.size >= @flush_threshold
    end
  end
end
