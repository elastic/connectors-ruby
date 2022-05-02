require 'concurrent'
require 'securerandom'

module ConnectorsAsync
  class JobStore
    def initialize
      @store = Concurrent::Hash.new
    end

    def create_job
      job_id = SecureRandom.uuid

      job = ConnectorsAsync::Job.new(job_id)

      @store[job_id] = job

      job # get one
    end

    def fetch_job(job_id)
      @store[job_id]
    end
  end
end
