#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module OutputSink
    class BaseSink
      def ingest(_document)
        raise 'not implemented'
      end

      def ingest_multiple(_documents)
        raise 'not implemented'
      end

      def delete(_id)
        raise 'not implemented'
      end

      def delete_multiple(_ids)
        raise 'not implemented'
      end

      def flush(_size: nil)
        raise 'not implemented'
      end

      def ingestion_stats
        raise 'not implemented'
      end
    end
  end
end
