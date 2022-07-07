#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
<<<<<<< HEAD
  module OutputSink
    class BaseSink
      def ingest(_document)
        raise 'not implemented'
      end

      def ingest_multiple(_documents)
        raise 'not implemented'
      end

      def delete_multiple(_ids)
        raise 'not implemented'
      end

      def flush(_size: nil)
=======
  module OutputSink 
    class BaseSink
      def ingest(document)
        raise 'not implemented'
      end

      def ingest_multiple(documents)
        raise 'not implemented'
      end

      def delete_multiple(ids)
        raise 'not implemented'
      end

      def flush(size: nil)
>>>>>>> 973c1b0 (Move sinks to core and its own namespace)
        raise 'not implemented'
      end
    end
  end
end
