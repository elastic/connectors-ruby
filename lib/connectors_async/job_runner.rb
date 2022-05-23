#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_app/config'
require 'connectors_async/job_store'
require 'connectors_shared/constants'
require 'connectors_shared/job_status'
require 'connectors_shared/exception_tracking'
require 'connectors_shared/logger'

module ConnectorsAsync
  class JobRunner
    class JobStuckError < StandardError; end

    def initialize(max_threads:)
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: max_threads,
        max_queue: 0,
        idletime: ConnectorsShared::Constants::IDLE_SLEEP_TIME + 1 # we +1 just so that thread.sleep manages to finish by the idle timeout
      )
    end

    def start_job(job:, connector_class:, secret_storage:, params:)
      @pool.post do
        init_thread

        connector = connector_class.new
        content_source_id = params[:content_source_id]
        cursors = params[:cursors] ||= {}
        cursors[:modified_since] = params.delete(:modified_since) if params[:modified_since]

        log_with_thread_id(:info, "Running the job #{job.id}")

        job.update_status(ConnectorsShared::JobStatus::RUNNING)

        new_cursors = connector.extract({ :content_source_id => content_source_id, :cursors => cursors, :secret_storage => secret_storage }) do |doc|
          with_throttling(job) do
            job.store(doc)
          end
        end

        job.update_status(ConnectorsShared::JobStatus::FINISHED)
        job.update_cursors(new_cursors)

        log_with_thread_id(:info, "Job #{job.id} has finished successfully")
      rescue StandardError => e
        log_with_thread_id(:error, "Job #{job.id} failed.")
        ConnectorsShared::ExceptionTracking.log_exception(e)
        job.fail(e)
      end
    end

    def log_with_thread_id(level, str)
      ConnectorsShared::Logger.public_send(level, "[Thread #{Thread.current.name}] #{str}")
    end

    private

    def with_throttling(job)
      attempts = 0
      if job.should_wait?
        log_with_thread_id(:info, "Job #{job.id} is sleeping: Enterprise Search hasn't picked up documents for a while.")

        while job.should_wait?
          if attempts < ConnectorsShared::Constants::MAX_IDLE_ATTEMPTS
            attempts += 1
            idle(ConnectorsShared::Constants::IDLE_SLEEP_TIME)
          else
            raise JobStuckError.new("Enterprise Search failed to collect the data from the queue, waited #{attempts} times for #{ConnectorsShared::Constants::IDLE_SLEEP_TIME} seconds.")
          end
        end

        log_with_thread_id(:info, "Job #{job.id} woke up")
      end

      yield
    end

    def idle(time)
      log_with_thread_id(:debug, "Idling for #{time} seconds")
      sleep(time)
    end

    def init_thread
      Time.zone = ActiveSupport::TimeZone.new('UTC') # bah Time.zone should be init for each thread
    end
  end
end
