#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Core
  module OutputSink
    class Sink
      def initialize(sink_strategy)
        @sink_strategy = sink_strategy
        @ingested_count = 0
        @ingested_volume = 0
        @deleted_count = 0
      end

      def ingest(document)
        unless document&.any?
          Utility::Logger.warn('Connector attempted to ingest an empty document, skipping')
          return
        end

        serialized_document = @sink_strategy.serialize(document)
        @sink_strategy.ingest(document['id'], serialized_document)

        @ingested_count += 1
        @ingested_volume += serialized_document.bytesize
      end

      def ingest_multiple(documents)
        documents.each { |doc| ingest(doc) }
      end

      def delete(id)
        return if id.nil?

        @sink_strategy.delete(id)

        @deleted_count += 1
      end

      def delete_multiple(ids)
        ids.each { |id| delete(id) }
      end

      def flush
        @sink_strategy.flush
      end

      def ingestion_stats
        {
          :indexed_document_count => @ingested_count,
          :indexed_document_volume => @ingested_volume,
          :deleted_document_count => @deleted_count
        }
      end

      private

      def do_ingest(_id, _serialized_document)
        raise NotImplementedError
      end

      def do_delete(_id)
        raise NotImplementedError
      end

      def do_flush
        raise NotImplementedError
      end

      def do_serialize(_document)
        raise NotImplementedError
      end
    end
  end
end
