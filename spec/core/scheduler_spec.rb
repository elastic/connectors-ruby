require 'core/native_scheduler'
require 'core/scheduler'
require 'core/elastic_connector_actions'
require 'core/filtering/validation_status'
require 'connectors/registry'

describe Core::Scheduler do
  subject { Core::NativeScheduler.new(poll_interval, heartbeat_interval) }

  let(:poll_interval) { 999 }
  let(:heartbeat_interval) { 999 }
  let(:connector_settings) { double }

  before(:each) do
    allow(connector_settings).to receive(:service_type).and_return('mongodb')
  end

  shared_examples_for 'triggers' do |task|
    it "yields #{task} task" do
      expect { |b| subject.when_triggered(&b) }.to yield_with_args(connector_settings, task)
    end
  end

  shared_examples_for 'does not trigger' do |task|
    it "does not yield #{task} task" do
      expect { |b| subject.when_triggered(&b) }.to_not yield_control
    end
  end

  describe '#when_triggered' do
    before(:each) do
      allow(subject).to receive(:connector_settings).and_return([connector_settings])
      subject.instance_variable_set(:@is_shutting_down, true)
    end

    context 'with sync task' do
      let(:allow_sync) { true }
      let(:sync_now) { false }
      let(:last_synced) { Time.now }
      let(:sync_enabled) { true }
      let(:sync_interval) { '0 0 * * * ?' }
      let(:scheduling_settings) do
        {
          :enabled => sync_enabled,
          :interval => sync_interval
        }
      end
      let(:valid_index_name) { true }
      let(:cron_parser) { instance_double(Fugit::Cron) }
      let(:next_trigger_time) { Time.now - 60 * 30 }

      before(:each) do
        allow(subject).to receive(:heartbeat_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:configuration_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:filtering_validation_triggered?).with(connector_settings).and_return(false)
        allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(allow_sync)
        allow(connector_settings).to receive(:id).and_return('123')
        allow(connector_settings).to receive(:connector_status).and_return('configured')
        allow(connector_settings).to receive(:[]).with(:sync_now).and_return(sync_now)
        allow(connector_settings).to receive(:[]).with(:last_synced).and_return(last_synced)
        allow(connector_settings).to receive(:scheduling_settings).and_return(scheduling_settings)
        allow(connector_settings).to receive(:valid_index_name?).and_return(valid_index_name)
        allow(connector_settings).to receive(:formatted).and_return('')

        allow(Utility::Cron).to receive(:quartz_to_crontab).with(sync_interval)
        allow(Fugit::Cron).to receive(:parse).and_return(cron_parser)
        allow(cron_parser).to receive(:next_time).and_return(next_trigger_time)
        allow(Time).to receive(:parse).and_return(nil)
      end

      it 'yields sync task' do
        expect { |b| subject.when_triggered(&b) }.to yield_with_args(connector_settings, :sync)
      end

      it_behaves_like 'triggers', :sync

      context 'when index name is invalid' do
        let(:valid_index_name) { false }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when connector is not ready to sync' do
        let(:allow_sync) { false }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when connector is set to sync now' do
        let(:sync_now) { true }

        it_behaves_like 'triggers', :sync
      end

      context 'when connector sync is disabled' do
        let(:sync_enabled) { false }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when connector sync interval is not configured' do
        let(:sync_interval) { nil }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when connector sync interval is not an invalid quartz' do
        before(:each) do
          allow(Utility::Cron).to receive(:quartz_to_crontab).with(sync_interval).and_raise(StandardError)
        end

        it_behaves_like 'does not trigger', :sync
      end

      context 'when connector sync interval cannot be parsed as a cron' do
        let(:cron_parser) { nil }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when next trigger time is in the future' do
        let(:next_trigger_time) { Time.now + 60 * 30 }

        it_behaves_like 'does not trigger', :sync
      end

      context 'when an error is thrown' do
        before(:each) do
          allow(subject).to receive(:sync_triggered?).and_raise(StandardError.new('Oh no!'))
        end

        it_behaves_like 'does not trigger', :sync
      end
    end

    context 'with heartbeat task' do
      let(:last_seen) { (Time.now - heartbeat_interval - 60 * 10).to_s }
      before(:each) do
        allow(subject).to receive(:sync_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:configuration_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:filtering_validation_triggered?).with(connector_settings).and_return(false)
        allow(connector_settings).to receive(:[]).with(:last_seen).and_return(last_seen)
      end

      it_behaves_like 'triggers', :heartbeat

      context 'when there\'s no last_seen' do
        let(:last_seen) { nil }

        it_behaves_like 'triggers', :heartbeat
      end

      context 'when last_seen is an invalid time' do
        before(:each) do
          allow(Time).to receive(:parse).with(last_seen).and_raise(ArgumentError)
        end

        it_behaves_like 'triggers', :heartbeat
      end

      context 'when last_sean is within the interval' do
        let(:last_seen) { Time.now.to_s }

        it_behaves_like 'does not trigger', :heartbeat
      end
    end

    context 'with configuration task' do
      let(:connector_status) { Connectors::ConnectorStatus::CREATED }
      let(:needs_service_type) { false }
      before(:each) do
        allow(subject).to receive(:sync_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:heartbeat_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:filtering_validation_triggered?).with(connector_settings).and_return(false)
        allow(connector_settings).to receive(:connector_status).and_return(connector_status)
        allow(connector_settings).to receive(:needs_service_type?).and_return(needs_service_type)
      end

      it_behaves_like 'triggers', :configuration

      # Regression bug!!!
      # We need to trigger configuration for the connector that was created with no service_type.
      # Otherwise on-prem connectors won't be able to start the flow at all.
      context 'when connector has no service_type' do
        let(:needs_service_type) { true }

        it_behaves_like 'triggers', :configuration
      end

      (Connectors::ConnectorStatus::STATUSES - [Connectors::ConnectorStatus::CREATED]).each do |status|
        context "when connector status is #{status}" do
          let(:connector_status) { status }

          it_behaves_like 'does not trigger', :configuration
        end
      end
    end

    context 'with filtering validation task' do
      let(:state) {
        Core::Filtering::ValidationStatus::EDITED
      }

      let(:advanced_config) {
        {
          :find => {
            :filter => {
              :$text => {
                :$search => 'garden',
                :$caseSensitive => false
              }
            },
            :options => {
              :skip => 10,
              :limit => 1000
            }
          }
        }
      }

      let(:validation) {
        {
          :state => state,
          :errors => []
        }
      }

      let(:filtering) {
        {
          :domain => 'DEFAULT',
          :active => {},
          :draft => {
            :rules => [],
            :advanced_snippet => advanced_config,
            :validation => validation
          }
        }
      }

      before(:each) do
        allow(subject).to receive(:sync_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:heartbeat_triggered?).with(connector_settings).and_return(false)
        allow(subject).to receive(:configuration_triggered?).with(connector_settings).and_return(false)

        allow(connector_settings).to receive(:filtering).and_return(filtering)
        allow(connector_settings).to receive(:formatted).and_return('MOCKED_VALUE')
      end

      context 'filtering is not present' do
        context 'filtering is nil' do
          let(:filtering) {
            nil
          }

          it_behaves_like 'does not trigger', :filter_validation
        end

        context 'filtering is an empty array' do
          let(:filtering) {
            []
          }

          it_behaves_like 'does not trigger', :filter_validation
        end

        context 'filtering is an empty hash' do
          let(:filtering) {
            {}
          }

          it_behaves_like 'does not trigger', :filter_validation
        end
      end

      context 'filtering does not contain draft field' do
        let(:filtering) {
          {
            :domain => 'DEFAULT',
            :active => {},
            :validation => {}
          }
        }

        it_behaves_like 'does not trigger', :filter_validation
      end

      context 'filtering draft advanced config is not present' do
        context 'advanced config is nil' do
          let(:advanced_config) {
            nil
          }

          context 'validation state is \'valid\'' do
            let(:state) {
              Core::Filtering::ValidationStatus::VALID
            }

            it_behaves_like 'does not trigger', :filter_validation
          end

          context 'validation state is \'edited\'' do
            let(:state) {
              Core::Filtering::ValidationStatus::EDITED
            }

            it_behaves_like 'triggers', :filter_validation
          end
        end

        context 'advanced config is empty' do
          let(:advanced_config) {
            {}
          }

          context 'validation state is \'valid\'' do
            let(:state) {
              Core::Filtering::ValidationStatus::VALID
            }

            it_behaves_like 'does not trigger', :filter_validation
          end

          context 'validation state is \'edited\'' do
            let(:state) {
              Core::Filtering::ValidationStatus::EDITED
            }

            it_behaves_like 'triggers', :filter_validation
          end
        end
      end

      context 'filtering validation is nil' do
        let(:validation) {
          nil
        }

        it_behaves_like 'does not trigger', :filter_validation
      end

      context 'filtering validation state is \'invalid\'' do
        let(:state) {
          Core::Filtering::ValidationStatus::INVALID
        }

        it_behaves_like 'does not trigger', :filter_validation
      end

      context 'filtering validation state is \'valid\'' do
        let(:state) {
          Core::Filtering::ValidationStatus::VALID
        }

        it_behaves_like 'does not trigger', :filter_validation
      end

      context 'filtering validation state is \'edited\'' do
        let(:state) {
          Core::Filtering::ValidationStatus::EDITED
        }

        it_behaves_like 'triggers', :filter_validation
      end
    end
  end
end
