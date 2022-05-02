require 'concurrent'

module ConnectorsAsync
  class Job
    def initialize(job_id)
      @data = Concurrent::Hash.new
      @data[:job_id] = job_id
      @data[:status] = ConnectorsAsync::JobStatus::CREATED
      @data[:documents] = Queue.new
    end

    def id
      @data[:job_id]
    end

    def status
      @data[:status]
    end

    def update_status(new_status)
      # add state machine logic here?
      @data[:status] = new_status
    end

    def fail(e)
      @data[:status] = ConnectorsAsync::JobStatus::FAILED
      @data[:error] = e
      puts e.to_json
    end

    def store_batch(batch)
      batch.each do |item|
        @data[:documents] << item
      end
    end

    def pop_batch(up_to: 20)
      results = []

      for i in 1..up_to do
        break if @data[:documents].empty?

        results << @data[:documents].pop
      end

      results
    end
  end
end
