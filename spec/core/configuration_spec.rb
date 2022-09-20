require 'core/configuration'
require 'connectors/connector_status'

describe Core::Configuration do
  describe '.update' do
    let(:connector_settings) { double }
    let(:connector_class) { double }
    let(:connector_status) { Connectors::ConnectorStatus::CREATED }
    let(:connector_id) { '123' }
    let(:service_type) { 'mongo' }
    let(:param_service_type) { nil }
    let(:needs_service_type) { false }
    let(:configuration) { { :foo => {} } }

    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:update_connector_fields)
      allow(Connectors::Registry).to receive(:connector_class).and_return(connector_class)
      allow(connector_settings).to receive(:id).and_return(connector_id)
      allow(connector_settings).to receive(:service_type).and_return(service_type)
      allow(connector_settings).to receive(:connector_status).and_return(connector_status)
      allow(connector_settings).to receive(:needs_service_type?).and_return(needs_service_type)
      allow(connector_settings).to receive(:formatted).and_return('')
      allow(connector_class).to receive(:configurable_fields).and_return(configuration)
    end

    (Connectors::ConnectorStatus::STATUSES - [Connectors::ConnectorStatus::CREATED]).each do |status|
      context "when connector status is #{status}" do
        let(:connector_status) { status }
        it 'updates nothing' do
          expect(Core::ElasticConnectorActions).to_not receive(:update_connector_fields)

          described_class.update(connector_settings, param_service_type)
        end
      end
    end

    context 'when connector class is not supported' do
      let(:connector_class) { nil }
      it 'updates nothing' do
        expect(Core::ElasticConnectorActions).to_not receive(:update_connector_fields)

        described_class.update(connector_settings, param_service_type)
      end
    end

    it 'updates configuration and status' do
      expect(Core::ElasticConnectorActions)
        .to receive(:update_connector_fields)
        .with(connector_id,
              hash_including(:configuration => configuration,
                             :status => Connectors::ConnectorStatus::NEEDS_CONFIGURATION))

      described_class.update(connector_settings)
    end

    context 'when all configurable fields are set' do
      let(:configuration) { { :foo => { :value => 'bar' } } }

      it 'updates status to configured' do
        expect(Core::ElasticConnectorActions)
          .to receive(:update_connector_fields)
          .with(connector_id,
                hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

        described_class.update(connector_settings, param_service_type)
      end
    end

    context 'when in non-native mode' do
      let(:service_type) { nil }
      let(:param_service_type) { 'mongo' }
      let(:needs_service_type) { true }

      it 'updates service type' do
        expect(Core::ElasticConnectorActions)
          .to receive(:update_connector_fields)
          .with(connector_id, hash_including(:service_type => param_service_type))

        described_class.update(connector_settings, param_service_type)
      end
    end
  end
end
