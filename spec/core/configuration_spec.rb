require 'core/configuration'
require 'connectors/base/connector'
require 'connectors/connector_status'
require 'active_support/core_ext/hash/indifferent_access'
require 'utility/constants'

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
      allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)
      allow(connector_settings).to receive(:id).and_return(connector_id)
      allow(connector_settings).to receive(:service_type).and_return(service_type)
      allow(connector_settings).to receive(:connector_status).and_return(connector_status)
      allow(connector_settings).to receive(:needs_service_type?).and_return(needs_service_type)
      allow(connector_settings).to receive(:formatted).and_return('')
      allow(connector_class).to receive(:configurable_fields).and_return(configuration)
      allow(connector_class).to receive(:configurable_fields_indifferent_access).and_return(configuration.with_indifferent_access)
      allow(connector_class).to receive(:kibana_features).and_return(Connectors::Base::Connector.kibana_features)
    end

    describe '.update' do
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
                hash_including(
                  :configuration => configuration,
                  :status => Connectors::ConnectorStatus::NEEDS_CONFIGURATION,
                  :features => {
                    Utility::Constants::FILTERING_RULES_FEATURE => true,
                    Utility::Constants::FILTERING_ADVANCED_FEATURE => true
                  }
                ))

        described_class.update(connector_settings)
      end

      context 'when all configurable fields are set with symbols' do
        let(:configuration) { { :foo => { :value => 'bar' } } }

        it 'updates status to configured' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

          described_class.update(connector_settings, param_service_type)
        end
      end

      context 'when all configurable fields are set with strings' do
        let(:configuration) { { 'foo' => { 'value' => 'bar' } } }

        it 'updates status to configured' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

          described_class.update(connector_settings, param_service_type)
        end
      end

      context 'when all configurable fields are set with a mix of strings and symbols' do
        let(:configuration) {
          {
            'foo' => {
              'value' => 'Foo'
            },
            :bar => {
              :value => 'Bar'
            }
          }
        }

        it 'updates status to configured' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

          described_class.update(connector_settings, param_service_type)
        end
      end

      context 'when not all configurable fields are set (with strings)' do
        let(:configuration) { { 'foo' => { 'value' => nil } } }

        it 'updates status to configured' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(:status => Connectors::ConnectorStatus::NEEDS_CONFIGURATION))

          described_class.update(connector_settings, param_service_type)
        end
      end

      context 'when not all configurable fields are set (with symbols)' do
        let(:configuration) { { :foo => { :value => nil } } }

        it 'updates status to configured' do
          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(:status => Connectors::ConnectorStatus::NEEDS_CONFIGURATION))

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
end
