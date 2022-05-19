#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_app/config'
require 'connectors_async/job_store'
require 'connectors_shared/job_status'
require 'connectors_shared/logger'

module ConnectorsAsync
  class JobRunner
    THROTTLE_SLEEP_TIME = 10

    def initialize(max_threads:)
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: max_threads,
        max_queue: 0,
        idletime: THROTTLE_SLEEP_TIME + 1 # we +1 just so that thread.sleep manages to finish by the idle timeout
      )
    end

    def start_job(job:, connector_class:, secret_storage:, params:)
      @pool.post do
        init_thread

        connector = connector_class.new
        content_source_id = params[:content_source_id]
        cursors = params[:cursors] ||= {}
        cursors[:modified_since] = params.delete(:modified_since) if params[:modified_since]

        log("Running the job #{job.id}")

        job.update_status(ConnectorsShared::JobStatus::RUNNING)

        new_cursors = connector.extract({ :content_source_id => content_source_id, :cursors => cursors, :secret_storage => secret_storage }) do |doc|
          job.store(doc)

          if job.should_throttle?
            log("Job #{job.id} is sleeping: Enterprise Search haven't picked up documents for a while.")

            idle(THROTTLE_SLEEP_TIME) while job.should_throttle?

            log("Job #{job.id} woke up")
          end
        end

        job.update_status(ConnectorsShared::JobStatus::FINISHED)
        job.update_cursors(new_cursors)

        log("Job #{job.id} has finished successfully")
      rescue StandardError => e
        job.fail(e)
        log("Job #{job.id} failed: #{e.message}")
      end
    end

    def log(str)
      # TODO: use proper logging
      puts("[#{Time.now.to_i}] [Thread #{Thread.current.object_id}] #{str}")
    end

    private

    def idle(time)
      Kernel.sleep(time)
    end

    def init_thread
      Time.zone = ActiveSupport::TimeZone.new('UTC') # bah Time.zone should be init for each thread
    end
  end
end
