#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'logger'
require 'active_support/core_ext/module'
require 'active_support/core_ext/string/filters'
require 'ecs_logging/logger'

module Utility
  class Logger
    SUPPORTED_LOG_LEVELS = %i[fatal error warn info debug].freeze
    MAX_SHORT_MESSAGE_LENGTH = 1000.freeze

    class << self

      delegate :formatter, :formatter=, :to => :logger

      def level=(log_level)
        logger.level = log_level
      end

      def logger
        @logger ||= Settings[:ecs_logging] ? EcsLogging::Logger.new(STDOUT) : ::Logger.new(STDOUT)
      end

      SUPPORTED_LOG_LEVELS.each do |level|
        define_method(level) do |message|
          if logger.is_a?(EcsLogging::Logger)
            logger.public_send(level, message, service: { name: 'connectors-ruby' })
          else
            logger.public_send(level, message)
          end
        end
      end

      def error_with_backtrace(message: nil, exception: nil, prog_name: nil)
        logger.error(prog_name) { message } if message
        logger.error exception.message if exception
        logger.error exception.backtrace.join("\n") if exception
      end

      def new_line
        logger.info("\n")
      end

      def generate_trace_id
        SecureRandom.uuid
      end

      def abbreviated_message(message)
        message.gsub(/\s+/, ' ').strip.truncate(MAX_SHORT_MESSAGE_LENGTH)
      end
    end
  end
end
