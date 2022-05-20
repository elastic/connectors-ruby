#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'connectors_shared/job_status'

# The class is actually supported for single-threaded usage EXCEPT for :documents field
# :documents are a Queue that's stated to be safe in a threaded environment
module ConnectorsAsync
  class Job
    class StatusUpdateError < StandardError; end
    class InvalidStatusError < StandardError; end

    def initialize(job_id)
      @data = {
        :job_id => job_id,
        :status => ConnectorsShared::JobStatus::CREATED,
        :documents => Queue.new
      }
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
      @data.has_key?(:cursors)
    end

    def cursors
      @data[:cursors]
    end

    def update_status(new_status)
      raise StatusUpdateError if is_finished?
      raise InvalidStatusError unless ConnectorsShared::JobStatus.is_valid?(new_status)

      @data[:status] = new_status
    end

    def update_cursors(new_cursors)
      @data[:cursors] = new_cursors
    end

    def fail(e)
      update_status(ConnectorsShared::JobStatus::FAILED)

      @data[:error] = e
    end

    def store(item)
      @data[:documents] << item
    end

    def pop_batch(up_to: 50)
      results = []

      up_to.times do
        break if @data[:documents].empty?

        results << @data[:documents].pop(true)
      end

      results
    rescue ThreadError
      puts 'Attempt to access an empty queue happened, when the queue was not supposed to be empty'
      results
    end

    def is_finished?
      status = @data[:status]

      [ConnectorsShared::JobStatus::FINISHED, ConnectorsShared::JobStatus::FAILED].include?(status)
    end

    def should_wait?
      @data[:documents].length > 500
    end
  end
end
