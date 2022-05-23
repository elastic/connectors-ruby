#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent/map'
require 'connectors_shared/constants'
require 'connectors_shared/job_status'
require 'connectors_shared/constants'

# The class is actually supported for single-threaded usage EXCEPT for :documents field
# :documents are a Queue that's stated to be safe in a threaded environment
module ConnectorsAsync
  class Job
    class StatusUpdateError < StandardError; end
    class InvalidStatusError < StandardError; end

    def initialize(job_id)
      # Imporatant:
      # Don't expose the @data outside
      # Don't allow to update @last_updated_at by anyone but this class
      # This is a naive implementation that can break, if any of these two conditions are not satisfied.

      @data = {
        :job_id => job_id,
        :status => ConnectorsShared::JobStatus::CREATED,
        :documents => Queue.new # queue is thread-safe
      }

      @last_updated_at = Time.now
    end

    def id
      @data[:job_id]
    end

    def status
      @data[:status]
    end

    def is_failed?
      @data[:status] == ConnectorsShared::JobStatus::FAILED
    end

    def error
      @data[:error]
    end

    def has_cursors?
      @data[:cursors].present?
    end

    def cursors
      @data[:cursors]
    end

    def update_status(new_status)
      raise StatusUpdateError if is_finished?
      raise InvalidStatusError unless ConnectorsShared::JobStatus.is_valid?(new_status)

      @data[:status] = new_status
      notify_changed
    end

    def update_cursors(new_cursors)
      @data[:cursors] = new_cursors
      notify_changed
    end

    def fail(e)
      update_status(ConnectorsShared::JobStatus::FAILED)

      @data[:error] = e
    end

    def store(item)
      @data[:documents] << item
      notify_changed
    end

    def pop_batch(up_to: 50)
      results = []

      up_to.times do
        break if @data[:documents].empty?

        results << @data[:documents].pop(true)
      end

      notify_changed
      results
    rescue ThreadError
      puts 'Attempt to access an empty queue happened, when the queue was not supposed to be empty'
      notify_changed
      results
    end

    def is_finished?
      status = @data[:status]

      [ConnectorsShared::JobStatus::FINISHED, ConnectorsShared::JobStatus::FAILED].include?(status)
    end

    def safe_to_clean_up?
      return true if is_finished? && @data[:documents].empty?

      # half an hour seems good enough, given that some connectors take 5-10 minutes to respond when throttled
      Time.now - @last_updated_at > ConnectorsShared::Constants::STALE_JOB_TIMEOUT
    end

    private

    def notify_changed
      @last_updated_at = Time.now
    end

    def should_wait?
      @data[:documents].length > ConnectorsShared::Constants::JOB_QUEUE_SIZE_IDLE_THRESHOLD
    end
  end
end
