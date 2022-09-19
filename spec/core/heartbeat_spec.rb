require 'core/heartbeat'
require 'connectors/connector_status'

describe Core::Heartbeat do
  describe '.send' do
    let(:connector_settings) { double }
    let(:connector_instance) { double }
    let(:connector_id) { '123' }
    let(:service_type) { 'mongo' }
    let(:configured) { false }
    let(:is_healthy) { true }
    let(:configuration) { {} }

    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:update_connector_fields)
      allow(Connectors::REGISTRY).to receive(:connector).and_return(connector_instance)
      allow(connector_settings).to receive(:id).and_return(connector_id)
      allow(connector_settings).to receive(:service_type).and_return(service_type)
      allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(configured)
      allow(connector_settings).to receive(:configuration).and_return(configuration)
      allow(connector_instance).to receive(:is_healthy?).and_return(is_healthy)
    end

    it 'updates last_seen' do
      expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:last_seen => anything))

      described_class.send(connector_settings)
    end

    context 'when it is configured' do
      let(:configured) { true }
      context 'when remote source is up' do
        let(:is_healthy) { true }

        it 'updates status' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(
              connector_id,
              hash_including(
                :status => Connectors::ConnectorStatus::CONNECTED
              )
            )

          described_class.send(connector_settings)
        end
      end

      context 'when remote source is down' do
        let(:is_healthy) { false }

        it 'updates status' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(
              connector_id,
              hash_including(
                :status => Connectors::ConnectorStatus::ERROR,
                :error => /Health check for 3d party service failed/
              )
            )

          described_class.send(connector_settings)
        end
      end
    end
  end
end
