require 'core/jobs/consumer'

describe Core::Jobs::Consumer do
  let(:scheduler) { double }
  let(:default_consumer_options) do
    {
      max_ingestion_queue_size: 100,
      max_ingestion_queue_bytes: 1000,
      scheduler: scheduler
    }
  end

  let(:index_name) { 'test_index' }

  describe '#initialize' do
    subject { described_class.new(default_consumer_options) }
    it 'creates a Consumer instance' do
      is_expected.to be_kind_of(Core::Jobs::Consumer)
    end

    it 'does not start consumer' do
      is_expected.not_to be_running
    end
  end

  describe '#subscribe' do
    subject { described_class.new(default_consumer_options) }
    let(:timer_task) { double }

    before(:example) do
      allow(Concurrent::TimerTask).to receive(:execute).and_return(timer_task)
      allow(timer_task).to receive(:running?).and_return(true)

      allow(Concurrent::ThreadPoolExecutor).to receive(:new).and_return(double)
    end

    it 'starts a concurrent timer task' do
      subject.subscribe!(index_name: index_name)

      expect(Concurrent::TimerTask).to have_received(:execute)
    end

    it 'starts a ThreadPoolExecutor pool' do
      subject.subscribe!(index_name: index_name)

      expect(Concurrent::ThreadPoolExecutor).to have_received(:new)
    end
  end

  describe '#shutdown' do
    subject { described_class.new(default_consumer_options) }

    let(:timer_task) { double }
    let(:pool) { double }

    before(:example) do
      allow(Concurrent::TimerTask).to receive(:execute).and_return(timer_task)
      allow(timer_task).to receive(:shutdown).and_return(true)

      allow(Concurrent::ThreadPoolExecutor).to receive(:new).and_return(pool)
      allow(pool).to receive(:shutdown).and_return(true)
      allow(pool).to receive(:wait_for_termination).and_return(true)

      subject.subscribe!(index_name: index_name)
    end

    it 'shutdowns the timer task' do
      subject.shutdown!

      expect(timer_task).to have_received(:shutdown)
    end

    it 'shutdowns the thread pool' do
      subject.shutdown!

      expect(pool).to have_received(:shutdown)
      expect(pool).to have_received(:wait_for_termination)
    end
  end

  class FakeTimerTask
    def self.assign_proc(execute_proc)
      @execute_proc = execute_proc
    end

    def self.execute_proc
      @execute_proc.call
    end
  end

  describe 'execute' do
    let(:pool) { double }

    before(:example) do
      allow(Concurrent::TimerTask).to receive(:execute) do |_args, &block|
        FakeTimerTask.assign_proc(block)
        FakeTimerTask
      end

      allow(pool).to receive(:post)
      allow(Concurrent::ThreadPoolExecutor).to receive(:new).and_return(pool)
    end

    context 'when there is no ready_for_sync connectors' do
      it 'does not post a job to the thread pool' do
        allow(scheduler).to receive(:connector_settings).and_return([])

        consumer = described_class.new(default_consumer_options)
        consumer.subscribe!(index_name: index_name)

        FakeTimerTask.execute_proc
        expect(pool).not_to have_received(:post)
      end
    end

    context 'when there are ready_for_sync connectors' do
      let(:connector_settings) { double }
      let(:connector_id) { '123' }
      let(:connector_index_name) { 'search-123' }

      let(:job) { double }
      let(:job_id) { '1234' }
      let(:pending_jobs) { [] }

      let(:consumer) { described_class.new(default_consumer_options) }

      before(:example) do
        allow(connector_settings).to receive(:id).and_return(connector_id)
        allow(connector_settings).to receive(:ready_for_sync?).and_return(true)
        allow(connector_settings).to receive(:formatted).and_return(connector_id.to_s)
        allow(connector_settings).to receive(:index_name).and_return(connector_index_name)

        allow(scheduler).to receive(:connector_settings).and_return([connector_settings])

        allow(job).to receive(:connector_id).and_return(connector_id)
        allow(job).to receive(:id).and_return(job_id)
        allow(Core::ConnectorJob).to receive(:pending_jobs).and_return(pending_jobs)

        consumer.subscribe!(index_name: index_name)
      end

      context 'when there are pending jobs' do
        let(:pending_jobs) { [job] }
        let(:sync_job_runner) { double }

        it 'posts a job to the thread pool' do
          FakeTimerTask.execute_proc

          expect(pool).to have_received(:post)
        end

        it 'executes SyncRunner' do
          allow_any_instance_of(Core::SyncJobRunner).to receive(:execute)
          allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)
          allow(Core::SyncJobRunner).to receive(:new).and_return(sync_job_runner)
          allow(sync_job_runner).to receive(:execute)

          allow(pool).to receive(:post) do |&block|
            block.call
          end

          FakeTimerTask.execute_proc

          expect(sync_job_runner).to have_received(:execute)
        end
      end

      context 'when there is no pedning jobs' do
        it 'does not post a job to the thread pool' do
          FakeTimerTask.execute_proc

          expect(pool).not_to have_received(:post)
        end
      end
    end
  end
end
