#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'concurrent'

require 'connectors_app/config'
require 'connectors_async/job_store'
require 'connectors_shared/job_status'

module ConnectorsAsync
  class JobRunner
    def initialize(max_threads:)
      @pool = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: max_threads, max_queue: 0)
    end

    def start_job(job:, connector_class:, cursors:, modified_since:, access_token:)
      @pool.post do
        Time.zone = ActiveSupport::TimeZone.new('UTC') # bah Time.zone should be init for each thread

        connector = connector_class.new

        log("Running the job #{job.id}")

        job.update_status(ConnectorsShared::JobStatus::RUNNING)

        cursors ||= {}
        cursors[:modified_since] = modified_since if modified_since

        new_cursors = connector.extract({ :cursors => cursors, :access_token => access_token }) do |doc|
          job.store(doc)
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
      puts("[#{Time.now.to_i}] [Thread #{Thread.current.object_id}] #{str}")
    end
  end
end
