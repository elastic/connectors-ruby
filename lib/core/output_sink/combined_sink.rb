#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/output_sink/base_sink'
require 'utility/logger'

module Core::OutputSink
  class CombinedSink < Core::OutputSink::BaseSink
    def initialize(sinks = [])
      @sinks = sinks
    end

    def ingest(document)
      @sinks.each { |sink| sink.ingest(document) }
    end

    def flush(size: nil)
      @sinks.each { |sink| sink.flush(size: size) }
    end

    def ingest_multiple(documents)
      @sinks.each { |sink| sink.ingest_multiple(documents) }
    end

    def delete_multiple(ids)
      @sinks.each { |sink| sink.delete_multiple(ids) }
    end
  end
end
