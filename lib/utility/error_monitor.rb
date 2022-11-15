#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'time'
require 'utility/errors'
require 'utility/exception_tracking'

module Utility
  class ErrorMonitor
    class MonitoringError < StandardError
      attr_accessor :tripped_by

      def initialize(message = nil, tripped_by: nil)
        super("#{message}#{tripped_by.present? ? " Tripped by - #{tripped_by.class}: #{tripped_by.message}" : ''}")
        @tripped_by = tripped_by
      end
    end

    class MaxSuccessiveErrorsExceededError < MonitoringError; end
    class MaxErrorsExceededError < MonitoringError; end
    class MaxErrorsInWindowExceededError < MonitoringError; end

    attr_reader :total_error_count, :success_count, :consecutive_error_count, :error_queue

    def initialize(
      max_errors: 1000,
      max_consecutive_errors: 10,
      max_error_ratio: 0.15,
      window_size: 100,
      error_queue_size: 20
    )
      @max_errors = max_errors
      @max_consecutive_errors = max_consecutive_errors
      @max_error_ratio = max_error_ratio
      @window_size = window_size
      @total_error_count = 0
      @success_count = 0
      @consecutive_error_count = 0
      @window_errors = Array.new(window_size) { false }
      @window_index = 0
      @last_error = nil
      @error_queue_size = error_queue_size
      @error_queue = []
    end

    def note_success
      @consecutive_error_count = 0
      @success_count += 1
      increment_window_index
    end

    def note_error(error, id: Time.now.to_i)
      stack_trace = Utility::ExceptionTracking.generate_stack_trace(error)
      error_message = Utility::ExceptionTracking.generate_error_message(error, nil, nil)
      Utility::Logger.debug("Message id: #{id} - #{error_message}\n#{stack_trace}")
      @total_error_count += 1
      @consecutive_error_count += 1
      @window_errors[@window_index] = true
      @error_queue << DocumentError.new(error.class.name, error_message, stack_trace, id)
      @error_queue = @error_queue.drop(1) if @error_queue.size > @error_queue_size
      increment_window_index
      @last_error = error

      raise_if_necessary
    end

    def finalize
      total_documents = @total_error_count + @success_count
      if total_documents > 0 && @total_error_count.to_f / total_documents > @max_error_ratio
        raise_with_last_cause(MaxErrorsInWindowExceededError.new("There were #{@total_error_count} errors out of #{total_documents} total documents", :tripped_by => @last_error))
      end
    end

    private

    def raise_if_necessary
      error =
        if @consecutive_error_count > @max_consecutive_errors
          MaxSuccessiveErrorsExceededError.new("Exceeded maximum consecutive errors - saw #{@consecutive_error_count} errors in a row.", :tripped_by => @last_error)
        elsif @total_error_count > @max_errors
          MaxErrorsExceededError.new("Exceeded maximum number of errors - saw #{@total_error_count} errors in total.", :tripped_by => @last_error)
        elsif @window_size > 0 && num_errors_in_window / @window_size > @max_error_ratio
          MaxErrorsInWindowExceededError.new("Exceeded maximum error ratio of #{@max_error_ratio}. Of the last #{@window_size} documents, #{num_errors_in_window} had errors", :tripped_by => @last_error)
        end

      raise_with_last_cause(error) if error
    end

    def num_errors_in_window
      @window_errors.count(&:itself).to_f
    end

    def increment_window_index
      @window_index = (@window_index + 1) % @window_size
    end

    def raise_with_last_cause(error)
      raise @last_error
    rescue StandardError
      raise error
    end
  end
end
