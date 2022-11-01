require 'json'

module Core::OutputSink
  class BulkQueue
    def initialize(count_threshold = 500, size_threshold = 5 * 1024 * 1024) # 500 items or 5MB
      @count_threshold = count_threshold.freeze
      @size_threshold = size_threshold.freeze

      @buffer = ''

      @current_op_size = 0

      @current_buffer_size = 0
      @current_data_size = 0

      @total_data_size = 0
    end

    def add_operation_with_payload(operation, payload)
      add_operation(operation)

      serialised_payload = serialise(payload)
      serialised_payload_size = serialised_payload.bytesize

      @buffer << serialised_payload
      @buffer << "\n"

      @current_buffer_size += serialised_payload_size
      @current_data_size += serialised_payload_size
      @total_data_size += serialised_payload_size
    end

    def add_operation(operation) 
      raise 'queue is full' if is_full?

      serialised_operation = serialise(operation)

      serialised_operation_size = serialised_operation.bytesize

      @buffer << serialised_operation
      @buffer << "\n"

      # update stats
      @current_op_size += 1
      @current_buffer_size += serialised_operation_size
    end

    def pop_request
      puts "Current op size: #{@current_op_size}"
      puts "Current buffer size: #{@current_buffer_size}"

      result = @buffer

      reset

      return result
    end

    def is_full?
      return true if @current_op_size >= @count_threshold
      return true if @current_buffer_size >= @size_threshold

      return false
    end

    def current_stats
      {
        :current_op_count => @current_op_size,
        :current_buffer_size => @current_buffer_size
      }
    end

    def total_stats
      {
        :total_data_size => @total_data_size
      }
    end

    private 
    def reset
      @current_op_size = 0
      @current_buffer_size = 0
      @current_data_size = 0

      @buffer = ''
    end

    def serialise(obj)
      JSON.generate(obj)
    end
  end
end
