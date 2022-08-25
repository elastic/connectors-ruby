require 'core/single_scheduler'
require 'active_support/core_ext/numeric/time'
require 'timecop'

describe Core::SingleScheduler do
  subject { described_class.new(connector_id, poll_interval) }

  let(:connector_id) { '123' }
  let(:poll_interval) { 999 }
  let(:connector_settings) { double }
  let(:last_synced) { Time.now - 1.day }
  let(:sync_now) { false }
  let(:connector_status) { 'SOME NICE STATUS' }
  let(:scheduling_enabled) { true }
  let(:scheduling_interval) { '0 * * * * *' }
  let(:scheduling_settings) { { :enabled => scheduling_enabled, :interval => scheduling_interval } }

  before(:each) do
    allow(Core::ConnectorSettings).to receive(:fetch).with(connector_id).and_return(connector_settings)

    allow(connector_settings).to receive(:id).and_return(connector_id)
    allow(connector_settings).to receive(:connector_status).and_return(connector_status)
    allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(true)
    allow(connector_settings).to receive(:[]).with(:last_synced).and_return(last_synced.to_s)
    allow(connector_settings).to receive(:[]).with(:sync_now).and_return(sync_now)
    allow(connector_settings).to receive(:scheduling_settings).and_return(scheduling_settings)

    # Scheduler will never stop, it's an infinite loop, thus to test it in a simpler way we trigger loop only 1 time here
    allow(subject).to receive(:loop).and_yield

    # Also we don't really wanna sleep
    allow_any_instance_of(Object).to receive(:sleep)
  end

  shared_examples_for 'sync triggers' do
    it '' do
      expect { |b| subject.when_triggered(&b) }.to yield_with_args(connector_settings)
    end
  end

  shared_examples_for 'sync does not trigger' do
    it '' do
      expect { |b| subject.when_triggered(&b) }.to_not yield_with_args(anything)
    end
  end

  describe '.when_triggered' do
    context 'when error is raised' do
      let(:error) { 'some error happened' }

      before(:each) do
        allow(connector_settings).to receive(:connector_status_allows_sync?).and_raise(error)
      end

      it_behaves_like 'sync does not trigger'

      it 'does not raise an error' do
        expect { |b| subject.when_triggered(&b) }.to_not raise_error
      end
    end

    context 'when scheduling is disabled' do
      let(:scheduling_enabled) { false }

      it_behaves_like 'sync does not trigger'
    end

    context 'when connector status does not allow sync' do
      before(:each) do
        allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(false)
      end

      it_behaves_like 'sync does not trigger'
    end

    context 'when connector has not synced yet' do
      let(:last_synced) { nil }

      it_behaves_like 'sync triggers'
    end

    context 'when sync_now flag is set to true' do
      let(:sync_now) { true }

      context 'when sync is disabled' do
        let(:scheduling_enabled) { false }

        it_behaves_like 'sync triggers'
      end

      context 'when connector status does not allow sync' do
        before(:each) do
          allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(false)
        end

        it_behaves_like 'sync does not trigger'
      end

      it_behaves_like 'sync triggers'
    end

    context 'when sync interval is not specified' do
      let(:scheduling_interval) { nil }

      it_behaves_like 'sync does not trigger'
    end

    context 'when cron parser is unable to parse the cron expression' do
      before(:each) do
        allow(Fugit::Cron).to receive(:parse).and_return(nil)
      end

      it_behaves_like 'sync does not trigger'
    end

    context 'when checking cron expression' do
      let(:now) { Time.new(2020, 1, 5) }
      let(:last_synced) { now - 1.hour }

      around(:each) do |example|
        Timecop.freeze(now) do
          example.run
        end
      end

      context 'when cron expression does not trigger sync' do
        let(:scheduling_interval) { '0 0 * * ? *' } # every day of month at 00:00
        it_behaves_like 'sync does not trigger'
      end

      context 'when cron expression should trigger sync' do
        let(:scheduling_interval) { '0 * * * ? *' } # every hour
        it_behaves_like 'sync triggers'
      end
    end
  end
end
