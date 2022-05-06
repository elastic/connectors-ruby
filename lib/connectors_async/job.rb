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

    def update_status(new_status)
      # add state machine logic here?
      raise StatusUpdateError if is_finished?

      @data[:status] = new_status
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

    rescue ThreadError => e
      puts "Attempt to access an empty queue happened, when the queue was not supposed to be empty"
      return []
    end

    def is_finished?
      status = @data[:status]

      [ConnectorsShared::JobStatus::FINISHED, ConnectorsShared::JobStatus::FAILED].include?(status)
    end
  end
end
