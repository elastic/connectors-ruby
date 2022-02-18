#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Swiftype
  class ExceptionTracking
    def self.capture_message(message, context = {})
      AppConfig.connectors_logger.error { "Error: #{message}. Context: #{context.inspect}" }

      # When the method is called from a rescue block, our return value may leak outside of its
      # intended scope, so let's explicitly return nil here to be safe.
      nil
    end

    def self.log_exception(exception, message = nil, context: nil, logger: AppConfig.connectors_logger)
      logger.error { message } if message
      logger.error { generate_stack_trace(exception) }
      logger.error { "Context: #{context.inspect}" } if context
    end

    def self.generate_error_message(exception, message, context)
      context = { :message_id => exception.id }.merge(context || {}) if exception.respond_to?(:id)
      context_message = context && "Context: #{context.inspect}"
      ['Exception', message, exception.class.to_s, exception.message, context_message]
        .compact
        .map { |part| part.to_s.dup.force_encoding('UTF-8') }
        .join(': ')
    end

    def self.generate_stack_trace(exception)
      full_message = exception.full_message

      cause = exception
      while cause.cause != cause && (cause = cause.cause)
        full_message << "Cause:\n#{cause.full_message}"
      end

      full_message.dup.force_encoding('UTF-8')
    end
  end
end
