#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_async/job'
require 'connectors_shared/logger'
require 'connectors_shared/exception_tracking'

module ConnectorsAsync
  class JobWatcher
    IDLE_TIME = 30 # seconds

    class AlreadyWatchingError < StandardError; end
    class JobTerminatedError < StandardError; end

    def initialize(job_store:)
      @job_store = job_store

      @is_watching = Concurrent::AtomicBoolean.new(false)
    end

    def watch
      raise AlreadyWatchingError.new('Already watching!') unless @is_watching.make_true
      ConnectorsShared::Logger.info('Watching after jobs {•̃_•̃}')

      Thread.new do
        loop do
          run!
        rescue StandardError => e
          ConnectorsShared::ExceptionTracking.log_exception(e)
        end
      end
    end

    private

    def run!
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
        ConnectorsShared::Logger.debug "Cleaning up #{job.id}"
        job.fail(JobTerminatedError.new) unless job.is_finished?
        @job_store.delete_job!(job.id)
      end

      idle(IDLE_TIME)
    end

    def idle(timeout)
      ConnectorsShared::Logger.debug "Idling for #{timeout}"
      sleep(timeout)
    end
  end
end
