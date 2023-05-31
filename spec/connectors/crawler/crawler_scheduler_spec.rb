require 'core/connector_settings'
require 'connectors/crawler/scheduler'

describe Connectors::Crawler::Scheduler do
  subject { described_class.new(poll_interval, heartbeat_interval) }

  let(:poll_interval) { 999 }
  let(:heartbeat_interval) { 999 }

  shared_examples_for 'triggers' do |key|
    it 'yields :sync task with an optional scheduling_key value' do
      expect { |b| subject.when_triggered(&b) }.to yield_with_args(connector_settings, :sync, key)
    end
  end

  shared_examples_for 'does not trigger' do |task|
    it "does not yield #{task} task" do
      expect { |b| subject.when_triggered(&b) }.to_not yield_control
    end
  end

  describe '#connector_settings' do
    context 'when elasticsearch query runs successfully' do
      let(:connector_settings) { [{ :id => '123' }] }
      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_crawler_connectors).and_return(connector_settings)
      end

      it 'fetches crawler connectors' do
        expect(subject.connector_settings).to eq(connector_settings)
      end
    end

    context 'when elasticsearch query fails' do
      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_crawler_connectors).and_raise(StandardError)
      end

      it 'fetches crawler connectors' do
        expect(subject.connector_settings).to be_empty
      end
    end
  end

  describe '#when_triggered' do
    let(:connector_settings) { double }

    before(:each) do
      allow(subject).to receive(:connector_settings).and_return([connector_settings])
      allow(connector_settings).to receive(:service_type).and_return('elastic-crawler')
      subject.instance_variable_set(:@is_shutting_down, true)
    end

    context 'when custom scheduling is present' do
      let(:connector_settings) { double }

      let(:sync_now) { false }
      let(:sync_enabled) { false }
      let(:sync_interval) { '0 0 * * * ?' }
      let(:full_sync_scheduling) do
        {
          :enabled => sync_enabled,
          :interval => sync_interval
        }
      end

      let(:weekly_enabled) { false }
      let(:weekly_interval) { '0 0 * * 1 ?' }
      let(:monthly_enabled) { false }
      let(:monthly_interval) { '0 0 * 1 * ?' }
      let(:custom_scheduling_settings) do
        {
          :weekly_key => {
            :name => 'weekly',
            :enabled => weekly_enabled,
            :interval => weekly_interval
          },
          :monthly_key => {
            :name => 'monthly',
            :enabled => monthly_enabled,
            :interval => monthly_interval
          }
        }
      end
      let(:custom_sync_triggered) { false }

      let(:next_trigger_time) { 1.day.from_now }
      let(:weekly_next_trigger_time) { 1.day.from_now }
      let(:monthly_next_trigger_time) { 1.day.from_now }

      let(:cron_parser) { instance_double(Fugit::Cron) }

      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_crawler_connectors).and_return(connector_settings)

        allow(subject).to receive(:sync_triggered?).with(connector_settings).and_call_original
        allow(subject).to receive(:custom_sync_triggered?).with(connector_settings).and_call_original

        allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(true)
        allow(connector_settings).to receive(:sync_now?).and_return(sync_now)
        allow(connector_settings).to receive(:full_sync_scheduling).and_return(full_sync_scheduling)
        allow(connector_settings).to receive(:custom_scheduling_settings).and_return(custom_scheduling_settings)
        allow(connector_settings).to receive(:valid_index_name?).and_return(true)
        allow(connector_settings).to receive(:formatted).and_return('Formatted')

        allow(Utility::Cron).to receive(:quartz_to_crontab).with(sync_interval)
        allow(Utility::Cron).to receive(:quartz_to_crontab).with(weekly_interval)
        allow(Utility::Cron).to receive(:quartz_to_crontab).with(monthly_interval)
        allow(Fugit::Cron).to receive(:parse).and_return(cron_parser)
      end

      context 'when none are enabled' do
        it_behaves_like 'does not trigger', :sync
      end

      context 'when one custom scheduling is enabled and ready to sync' do
        let(:monthly_enabled) { true }
        let(:monthly_next_trigger_time) { Time.now + poll_interval - 10 }

        before(:each) do
          allow(Utility::Cron).to receive(:quartz_to_crontab).with(monthly_interval)
          allow(cron_parser).to receive(:next_time).and_return(monthly_next_trigger_time)
        end

        it_behaves_like 'triggers', :monthly_key
      end

      context 'when all custom schedulings are enabled and ready to sync' do
        let(:weekly_enabled) { true }
        let(:monthly_enabled) { true }

        let(:weekly_next_trigger_time) { Time.now + poll_interval - 10 }
        let(:monthly_next_trigger_time) { Time.now + poll_interval - 10 }

        before(:each) do
          allow(cron_parser).to receive(:next_time).and_return(weekly_next_trigger_time, monthly_next_trigger_time)
        end

        # it will return the first custom scheduling it encounters
        it_behaves_like 'triggers', :weekly_key
      end

      context 'when base scheduling and all custom scheduling are enabled and require a sync' do
        let(:sync_enabled) { true }
        let(:weekly_enabled) { true }
        let(:monthly_enabled) { true }

        let(:next_trigger_time) { Time.now + poll_interval - 10 }
        let(:weekly_next_trigger_time) { Time.now + poll_interval - 10 }
        let(:monthly_next_trigger_time) { Time.now + poll_interval - 10 }

        before(:each) do
          allow(cron_parser).to receive(:next_time).and_return(next_trigger_time, weekly_next_trigger_time, monthly_next_trigger_time)
        end

        # it will return the base scheduling
        it_behaves_like 'triggers', nil
      end
    end
  end
end
