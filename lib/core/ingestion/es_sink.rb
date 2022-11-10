#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/config'
require 'utility/bulk_queue'
require 'utility/es_client'
require 'utility/logger'
require 'elasticsearch/api'

module Core
  module Ingestion
    class EsSink
      def initialize(index_name, request_pipeline, bulk_queue = Utility::BulkQueue.new)
        @client = Utility::EsClient.new(App::Config[:elasticsearch])
        @index_name = index_name
        @request_pipeline = request_pipeline
        @operation_queue = bulk_queue

        @queued = {
          :indexed_document_count => 0,
          :deleted_document_count => 0,
          :indexed_document_volume => 0
        }

        @completed = {
          :indexed_document_count => 0,
          :deleted_document_count => 0,
          :indexed_document_volume => 0
        }
      end

      def ingest(document)
        unless document&.any?
          Utility::Logger.warn('Connector attempted to ingest an empty document, skipping')
          return
        end

        id = document['id']
        serialized_document = serialize(document)
        index_op = serialize({ 'index' => { '_index' => @index_name, '_id' => id } })

        flush unless @operation_queue.will_fit?(index_op, serialized_document)

        @operation_queue.add(
          index_op,
          serialized_document
        )
        @queued[:indexed_document_count] += 1
        @queued[:indexed_document_volume] += serialized_document.bytesize
      end

      def ingest_multiple(documents)
        documents.each { |doc| ingest(doc) }
      end

      def delete(id)
        return if id.nil?

        delete_op = serialize({ 'delete' => { '_index' => @index_name, '_id' => id } })
        flush unless @operation_queue.will_fit?(delete_op)

        @operation_queue.add(delete_op)
        @queued[:deleted_document_count] += 1
      end

      def delete_multiple(ids)
        ids.each { |id| delete(id) }
      end

      def flush
        data = @operation_queue.pop_all
        return if data.empty?

        @client.bulk(:body => data, :pipeline => @request_pipeline)

        @completed[:indexed_document_count] += @queued[:indexed_document_count]
        @completed[:deleted_document_count] += @queued[:deleted_document_count]
        @completed[:indexed_document_volume] += @queued[:indexed_document_volume]

        @queued[:indexed_document_count] = 0
        @queued[:deleted_document_count] = 0
        @queued[:indexed_document_volume] = 0
      end

      def ingestion_stats
        @completed.dup
      end

      private

      def serialize(document)
        Elasticsearch::API.serializer.dump(document)
      end
    end
  end
end
