#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_async/job_store'
require 'connectors_shared/job_status'

module ConnectorsAsync
  class JobRunner
    def initialize
      @pool = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 4, max_queue: 0)
    end

    def start_job(job:, connector_class:, modified_since:, access_token:)
      @pool.post do
        connector = connector_class.new

        log("Running the job #{job.id}")
        Time.zone = ActiveSupport::TimeZone.new('UTC') # bah Time.zone should be init for each thread

        job.update_status(ConnectorsShared::JobStatus::RUNNING)

        cursors = { :modified_since => modified_since }
        connector.extract({ :cursors => cursors }) do |doc|
          job.store(doc)
        end

        job.update_status(ConnectorsShared::JobStatus::FINISHED)
        log("Job #{job.id} has finished successfully")
      rescue StandardError => e
        job.fail(e)
        log("Job #{job.id} failed: #{e.message}")
      end
    end

    def log(str)
      puts("[#{Time.now.to_i}] [Thread #{Thread.current.object_id}] #{str}")
    end
  end
end
