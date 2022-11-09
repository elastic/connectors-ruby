#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Core
  module OutputSink
    class ConsoleStrategy
      def ingest(id, serialized_document)
        print_header "Got a single document[id=#{id}]"
        puts serialized_document
      end

      def delete(doc_id)
        print_header "Deleting single id: #{doc_id}"
        puts doc_id
      end

      def flush
        print_header 'Flushing'
      end

      def serialize(obj)
        obj.to_json
      end

      private

      def print_delim
        puts '----------------------------------------------------'
      end

      def print_header(header)
        print_delim
        puts header
        print_delim
      end
    end
  end
end
