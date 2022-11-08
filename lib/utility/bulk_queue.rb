#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'json'

module Utility
  class BulkQueue
    class QueueOverflowError < StandardError; end

    # 500 items or 5MB
    def initialize(operation_count_threshold = 500, size_threshold = 5 * 1024 * 1024)
      @operation_count_threshold = operation_count_threshold.freeze
      @size_threshold = size_threshold.freeze

      @buffer = ''

      @current_operation_count = 0

      @current_buffer_size = 0
      @current_data_size = 0
    end

    def pop_all
      result = @buffer

      reset

      result
    end

    def add(operation, payload = nil)
      raise QueueOverflowError unless will_fit?(operation, payload)

      operation_size = get_size(operation)
      payload_size = get_size(payload)

      @current_operation_count += 1
      @current_buffer_size += operation_size
      @current_buffer_size += payload_size
      @current_data_size += payload_size

      @buffer << operation
      @buffer << "\n"

      if payload
        @buffer << payload
        @buffer << "\n"
      end
    end

    def will_fit?(operation, payload = nil)
      return false if @current_operation_count + 1 > @operation_count_threshold

      operation_size = get_size(operation)
      payload_size = get_size(payload)

      @current_buffer_size + operation_size + payload_size < @size_threshold
    end

    def current_stats
      {
        :current_operation_count => @current_operation_count,
        :current_buffer_size => @current_buffer_size
      }
    end

    private

    def get_size(str)
      return 0 unless str
      str.bytesize
    end

    def reset
      @current_operation_count = 0
      @current_buffer_size = 0
      @current_data_size = 0

      @buffer = ''
    end
  end
end
