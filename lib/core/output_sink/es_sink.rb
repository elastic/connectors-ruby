#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'app/config'
require 'core/output_sink/base_sink'
require 'core/output_sink/bulk_queue'
require 'utility/es_client'
require 'utility/logger'

module Core::OutputSink
  class EsSink < Core::OutputSink::BaseSink

    def initialize(index_name, request_pipeline)
      super()
      @client = Utility::EsClient.new(App::Config[:elasticsearch])
      @index_name = index_name
      @request_pipeline = request_pipeline
      @operation_queue = Core::OutputSink::BulkQueue.new
      @ingested_count = 0
      @deleted_count = 0
    end

    def ingest(document)
      return if document.blank?

      index_op = serialize({ 'index' => { '_index' => index_name, '_id' => document['id'] } })
      index_data = serialize(document)

      flush unless @operation_queue.will_fit?(index_op, index_data)

      @operation_queue.add(
        index_op,
        index_data
      )

      @ingested_count += 1
    end

    def delete(doc_id)
      return if doc_id.nil?

      delete_op = serialize({ 'delete' => { '_index' => index_name, '_id' => doc_id } })
      flush unless @operation_queue.will_fit?(delete_op)

      @operation_queue.add(delete_op)

      @deleted_count += 1
    end

    def flush
      stats = @operation_queue.current_stats
      data = @operation_queue.pop_request
      return if data.empty?

      @client.bulk(:body => data, :pipeline => @request_pipeline)
      Utility::Logger.info "Applied #{stats[:current_op_count]} upsert/delete operations to the index #{index_name}."
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
        :indexed_document_count => @ingested_count,
        :indexed_document_volume => @operation_queue.total_stats[:total_data_size],
        :deleted_document_count => @deleted_count
      }
    end

    private

    def serialize(obj)
      # TODO: actually properly serialize
      # Now dates are serialized like strings
      JSON.generate(obj)
    end

    attr_accessor :index_name
  end
end
