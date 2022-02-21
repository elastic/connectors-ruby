#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'stubs/app_config' unless defined?(Rails)
require 'active_support/core_ext/module'

module ConnectorsShared
  class Logger
    SUPPORTED_LOG_LEVELS = %i[fatal error warn info debug].freeze

    class << self

      delegate :formatter, :formatter=, :to => :logger

      def setup!(logger)
        @logger = logger
      end

      def logger
        @logger ||= AppConfig.connectors_logger
      end

      SUPPORTED_LOG_LEVELS.each do |level|
        define_method(level) do |message|
          logger.public_send(level, message)
        end
      end
    end
  end
end
