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
#
# This class is responsible for sending the data to the data storage.
# While we don't actually allow to output our data anywhere except
# Elasticsearch, we still want to be able to do so sometime in future.
#
# This class should stay simple and any change to the class should be careful
# with the thought of introducing other sinks in future.
module Core
  module Ingestion
    class EsSink
      def initialize(index_name, request_pipeline, bulk_queue = Utility::BulkQueue.new, max_allowed_document_size = 5 * 1024 * 1024)
        @client = Utility::EsClient.new(App::Config[:elasticsearch])
        @index_name = index_name
        @request_pipeline = request_pipeline
        @operation_queue = bulk_queue

        @max_allowed_document_size = max_allowed_document_size

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
        if document.nil? || document.empty?
          Utility::Logger.warn('Connector attempted to ingest an empty document, skipping')
          return
        end

        id = document['id']
        serialized_document = serialize(document)

        document_size = serialized_document.bytesize

        if @max_allowed_document_size > 0 && document_size > @max_allowed_document_size
          Utility::Logger.warn("Connector attempted to ingest too large document with id=#{document['id']} [#{document_size}/#{@max_allowed_document_size}], skipping the document.")
          return
        end

        index_op = serialize({ 'index' => { '_index' => @index_name, '_id' => id } })

        flush unless @operation_queue.will_fit?(index_op, serialized_document)

        @operation_queue.add(
          index_op,
          serialized_document
        )

        @queued[:indexed_document_count] += 1
        @queued[:indexed_document_volume] += document_size
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
