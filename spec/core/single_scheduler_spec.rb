require 'core/connector_settings'
require 'core/single_scheduler'

describe Core::SingleScheduler do
  subject { described_class.new(connector_id, poll_interval, heartbeat_interval) }

  let(:connector_id) { '123' }
  let(:poll_interval) { 999 }
  let(:heartbeat_interval) { 999 }

  describe '#connector_settings' do
    context 'when elasticsearch query runs successfully' do
      let(:connector_setting) { double }
      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_by_id).with(connector_id).and_return(connector_setting)
      end

      it 'fetches the connector' do
        expect(subject.connector_settings).to eq([connector_setting])
      end

      context 'when connector does not exist' do
        let(:connector_setting) { nil }

        it 'fetches no connector' do
          expect(subject.connector_settings).to be_empty
        end
      end
    end

    context 'when elasticsearch query fails' do
      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_by_id).with(connector_id).and_raise(StandardError)
      end

      it 'fetches no connector' do
        expect(subject.connector_settings).to be_empty
      end
    end

    context 'when authorization error appears' do
      before(:each) do
        allow(Core::ConnectorSettings).to receive(:fetch_by_id).and_raise(Elastic::Transport::Transport::Errors::Unauthorized, 'Unauthorized')
      end

      it 'rethrows error' do
        expect { subject.connector_settings }.to raise_error(Elastic::Transport::Transport::Errors::Unauthorized, 'Unauthorized')
      end
    end
  end
end
