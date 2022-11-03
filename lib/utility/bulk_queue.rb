#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'json'

module Utility
  class BulkQueue
    def initialize(count_threshold = 500, size_threshold = 5 * 1024 * 1024) # 500 items or 5MB
      @count_threshold = count_threshold.freeze
      @size_threshold = size_threshold.freeze

      @buffer = ''

      @current_op_count = 0

      @current_buffer_size = 0
      @current_data_size = 0

      @total_data_size = 0
    end

    def pop_request
      result = @buffer

      reset

      return result
    end

    def add(operation, payload = nil)
      raise 'We will overflow!!!!' unless will_fit?(operation, payload) #TODO: actual error class

      operation_size = get_size(operation)
      payload_size = get_size(payload)

      @current_op_count += 1
      @current_buffer_size += operation_size
      @current_buffer_size += payload_size
      @current_data_size += payload_size
      @total_data_size += payload_size

      @buffer << operation
      @buffer << "\n"

      if payload
        @buffer << payload
        @buffer << "\n"
      end
    end

    def will_fit?(operation, payload = nil)
      return false if @current_op_count + 1 >= @count_threshold

      operation_size = get_size(operation)
      payload_size = get_size(payload)

      @current_buffer_size + operation_size + payload_size < @size_threshold
    end

    def current_stats
      {
        :current_op_count => @current_op_count,
        :current_buffer_size => @current_buffer_size
      }
    end

    def total_stats
      {
        :total_data_size => @total_data_size
      }
    end

    private 

    def get_size(str)
      return 0 if !str
      return str.bytesize
    end

    def reset
      @current_op_count = 0
      @current_buffer_size = 0
      @current_data_size = 0

      @buffer = ''
    end
  end
end
