#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'
require 'utility/logger'

module Utility
  class ExceptionTracking
    class << self
      def capture_message(message, context = {})
        Utility::Logger.error("Error: #{message}. Context: #{context.inspect}")

        # When the method is called from a rescue block, our return value may leak outside of its
        # intended scope, so let's explicitly return nil here to be safe.
        nil
      end

      def capture_exception(exception, context = {})
        Utility::Logger.error(generate_stack_trace(exception))
        Utility::Logger.error("Context: #{context.inspect}") if context
      end

      def log_exception(exception, message = nil)
        Utility::Logger.error(message) if message
        Utility::Logger.error(generate_stack_trace(exception))
      end

      def augment_exception(exception)
        unless exception.respond_to?(:id)
          exception.instance_eval do
            def id
              @error_id ||= BSON::ObjectId.new.to_s
            end
          end
        end
      end

      def generate_error_message(exception, message, context)
        context = { :message_id => exception.id }.merge(context || {}) if exception.respond_to?(:id)
        context_message = context && "Context: #{context.inspect}"
        ['Exception', message, exception.class.to_s, exception.message, context_message]
          .compact
          .map { |part| part.to_s.dup.force_encoding('UTF-8') }
          .join(': ')
      end

      def generate_stack_trace(exception)
        full_message = exception.full_message

        cause = exception
        while cause.cause != cause && (cause = cause.cause)
          full_message << "Cause:\n#{cause.full_message}"
        end

        full_message.dup.force_encoding('UTF-8')
      end
    end
  end
end
