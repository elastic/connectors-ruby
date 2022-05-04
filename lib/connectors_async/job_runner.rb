require 'concurrent'

module ConnectorsAsync
  class JobRunner
    def initialize
      @pool = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 4, max_queue: 0)
      @job_store = ConnectorsAsync::JobStore.new
    end

    def start_job(connector:, modified_since:, access_token:)
      job = @job_store.create_job

      @pool.post do
        begin
          Time.zone = ActiveSupport::TimeZone.new('UTC') # bah Time.zone should be init for each thread

          job.update_status(JobStatus::RUNNING)

          cursors = { :modified_since => modified_since }
          connector.extract({:access_token => access_token, :cursors => cursors }) do |doc|
            job.store( doc )
          end

          job.update_status(JobStatus::FINISHED)
        rescue StandardError => e
          job.fail(e)
        end
      end

      job.id
    end

    def fetch_job_results(job_id)
      job = @job_store.fetch_job(job_id)

      job.pop_batch
    end

    def fetch_job_status(job_id)
      job = @job_store.fetch_job(job_id)

      job.status
    end
  end
end
