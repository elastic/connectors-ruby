#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'stubs/swiftype/exception_tracking' unless defined?(Rails)
require 'bson'
require 'connectors_shared/logger'

module ConnectorsShared
  class ExceptionTracking
    class << self
      def capture_message(message, context = {})
        Swiftype::ExceptionTracking.capture_message(message, context)
      end

      def capture_exception(exception, context = {})
        Swiftype::ExceptionTracking.log_exception(exception, :context => context)
      end

      def log_exception(exception, message = nil)
        Swiftype::ExceptionTracking.log_exception(exception, message, :logger => ConnectorsShared::Logger.logger)
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
    end
  end
end
