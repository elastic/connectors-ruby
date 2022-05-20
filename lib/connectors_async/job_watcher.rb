#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_shared/logger'

module ConnectorsAsync
  class JobWatcher
    IDLE_TIME = 3 # seconds

    def initialize(job_store:)
      @job_store = job_store

      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: 1,
        max_queue: 0,
        idletime: IDLE_TIME + 1
      )

      @is_watching = Concurrent::AtomicBoolean.new(false)
    end

    def watch
      raise 'Already watching!' unless @is_watching.make_true
      ConnectorsShared::Logger.info('Watching after jobs {•̃_•̃}')

      @pool.post do
        Kernel.loop do
          jobs_to_clean_up = []

          jobs = @job_store.fetch_all

          ConnectorsShared::Logger.debug("Found #{jobs.length} jobs.")

          jobs.each do |job|
            if job.safe_to_clean_up?
              jobs_to_clean_up << job
            end
          end

          ConnectorsShared::Logger.debug("Found #{jobs_to_clean_up.length} jobs to clean up.")

          jobs_to_clean_up.each do |job|
            ConnectorsShared::Logger.info "Cleaning up #{job.id}"
            @job_store.delete_job!(job.id)
          end

          idle(IDLE_TIME)
        end
      end
    end

    private

    def idle(timeout)
      Kernel.sleep(timeout)
    end
  end
end
