#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'app/config'
require 'core/output_sink/base_sink'
require 'utility/bulk_queue'
require 'utility/es_client'
require 'utility/logger'
require 'elasticsearch/api'

module Core::OutputSink
  class EsSink < Core::OutputSink::BaseSink

    def initialize(index_name, request_pipeline, bulk_queue = Utility::BulkQueue.new)
      super()
      @client = Utility::EsClient.new(App::Config[:elasticsearch])
      @index_name = index_name
      @request_pipeline = request_pipeline
      @operation_queue = bulk_queue
    end

    private

    def do_ingest(id, serialized_document)
      index_op = do_serialize({ 'index' => { '_index' => index_name, '_id' => id } })

      flush unless @operation_queue.will_fit?(index_op, serialized_document)

      @operation_queue.add(
        index_op,
        serialized_document
      )
    end

    def do_delete(doc_id)
      delete_op = do_serialize({ 'delete' => { '_index' => index_name, '_id' => doc_id } })
      flush unless @operation_queue.will_fit?(delete_op)

      @operation_queue.add(delete_op)
    end

    def do_flush
      data = @operation_queue.pop_all
      return if data.empty?

      @client.bulk(:body => data, :pipeline => @request_pipeline)
    end

    def do_serialize(obj)
      Elasticsearch::API.serializer.dump(obj)
    end

    attr_accessor :index_name
  end
end
