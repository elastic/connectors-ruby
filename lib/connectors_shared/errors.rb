#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'active_support/core_ext/string'

module ConnectorsShared
  class DocumentError
    attr_accessor :error_class, :error_message, :stack_trace, :error_id

    def initialize(error_class, error_message, stack_trace, error_id)
      @error_class = error_class
      @error_message = error_message
      @error_id = error_id

      # keywords must be < 32kb, UTF-8 chars can be up to 3 bytes, thus 32k/3 ~= 10k
      # See https://github.com/elastic/workplace-search-team/issues/1723
      @stack_trace = stack_trace.truncate(10_000)
    end

    def to_h
      {
        'error_class' => error_class,
        'error_message' => error_message,
        'stack_trace' => stack_trace,
        'error_id' => error_id
      }
    end
  end

  class ClientError < StandardError; end
  class EvictionWithNoProgressError < StandardError; end
  class EvictionError < StandardError
    attr_accessor :cursors

    def initialize(message = nil, cursors: nil)
      super(message)
      @cursors = cursors
    end
  end

  class SuspendedJobError < StandardError
    attr_accessor :suspend_until, :cursors

    def initialize(message = nil, suspend_until:, cursors: nil)
      super(message)
      @suspend_until = suspend_until
      @cursors = cursors
    end
  end
  class ThrottlingError < SuspendedJobError; end
  class TransientServerError < SuspendedJobError; end
  class UnrecoverableServerError < StandardError; end
  class TransientSubextractorError < StandardError; end
  class JobDocumentLimitError < StandardError; end
  class JobClaimingError < StandardError; end

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

  class JobSyncNotPossibleYetError < StandardError
    attr_accessor :sync_will_be_possible_at

    def initialize(message = nil, sync_will_be_possible_at: nil)
      human_readable_errors = []

      human_readable_errors.push(message) unless message.nil?
      human_readable_errors.push("Content source was created too recently to schedule jobs, next job scheduling is possible at #{sync_will_be_possible_at}.") unless sync_will_be_possible_at.nil?

      super(human_readable_errors.join(' '))
    end
  end
  class PlatinumLicenseRequiredError < StandardError; end
  class JobInterruptedError < StandardError; end
  class JobCannotBeUpdatedError < StandardError; end
  class SecretInvalidError < StandardError; end
  class InvalidIndexingConfigurationError < StandardError; end
  class TokenRefreshFailedError < StandardError; end
  class ConnectorNotAvailableError < StandardError; end

  # For when we want to explicitly set a #cause but can't
  class ExplicitlyCausedError < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
    end
  end

  class PublishingFailedError < ExplicitlyCausedError; end

  class Error
    attr_reader :status_code, :code, :message

    def initialize(status_code, code, message)
      @status_code = status_code
      @code = code
      @message = message
    end

    def to_h
      {
        'code' => @code,
        'message' => @message
      }
    end
  end

  INTERNAL_SERVER_ERROR = ConnectorsShared::Error.new(500, 'INTERNAL_SERVER_ERROR', 'Internal server error')
  INVALID_API_KEY = ConnectorsShared::Error.new(401, 'INVALID_API_KEY', 'Invalid API key')
  UNSUPPORTED_AUTH_SCHEME = ConnectorsShared::Error.new(401, 'UNSUPPORTED_AUTH_SCHEME', 'Unsupported authorization scheme')
  INVALID_ACCESS_TOKEN = ConnectorsShared::Error.new(401, 'INVALID_ACCESS_TOKEN', 'Invalid/expired access token, please refresh the token')
  TOKEN_REFRESH_ERROR = ConnectorsShared::Error.new(401, 'TOKEN_REFRESH_ERROR', 'Failed to refresh token, please re-authenticate the application')
end
