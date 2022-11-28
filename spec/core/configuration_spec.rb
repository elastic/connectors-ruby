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
    let(:configurable_fields) { { :foo => {} } }
    let(:needs_configuration) { true }

    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:update_connector_fields)
      allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)
      allow(connector_settings).to receive(:id).and_return(connector_id)
      allow(connector_settings).to receive(:service_type).and_return(service_type)
      allow(connector_settings).to receive(:connector_status).and_return(connector_status)
      allow(connector_settings).to receive(:configuration).and_return(configuration)
      allow(connector_settings).to receive(:needs_service_type?).and_return(needs_service_type)
      allow(connector_settings).to receive(:formatted).and_return('')
      allow(connector_settings).to receive(:needs_configuration?).and_return(needs_configuration)
      allow(connector_class).to receive(:configurable_fields).and_return(configurable_fields)
      allow(connector_class).to receive(:configurable_fields_indifferent_access).and_return(configurable_fields.with_indifferent_access)
      allow(connector_class).to receive(:kibana_features).and_return(Connectors::Base::Connector.kibana_features)
    end

    describe '.update' do
      shared_examples_for 'updates nothing' do
        it '' do
          expect(Core::ElasticConnectorActions).to_not receive(:update_connector_fields)

          described_class.update(connector_settings, param_service_type)
        end
      end

      shared_examples_for 'updates status' do |expected_status, expected_configuration|
        it "updates to #{expected_status}" do
          expected_hash = { :status => expected_status }.tap do |expected_doc|
            expected_doc[:configuration] = expected_configuration if expected_configuration.present?
          end

          expect(Core::ElasticConnectorActions)
            .to receive(:update_connector_fields)
            .with(connector_id,
                  hash_including(expected_hash))

          described_class.update(connector_settings, param_service_type)
        end
      end

      context 'when connector does not need configuration' do
        let(:needs_configuration) { false }

        it_behaves_like 'updates nothing'
      end

      context 'when connector class is not supported' do
        let(:connector_class) { nil }

        it_behaves_like 'updates nothing'
      end

      context 'when connectors needs configuration' do
        let(:needs_configuration) { true }

        context 'when all configurable fields are set with symbols' do
          let(:configurable_fields) { { :foo => { :value => 'bar' } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED, { :foo => { :value => 'bar' } }
        end

        context 'when all configurable fields are set with strings' do
          let(:configurable_fields) { { 'foo' => { 'value' => 'bar' } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED, { 'foo' => { 'value' => 'bar' } }
        end

        context 'when all configurable fields are set with a mix of strings and symbols' do
          let(:configurable_fields) {
            {
              'foo' => {
                'value' => 'Foo'
              },
              :bar => {
                :value => 'Bar'
              }
            }
          }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED, { 'foo' => { 'value' => 'Foo' }, :bar => { :value => 'Bar' } }
        end

        context 'when configuration is not set (with strings)' do
          let(:configurable_fields) { { 'foo' => { 'value' => nil } } }
          let(:configuration) { { 'foo' => { 'value' => nil } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::NEEDS_CONFIGURATION
        end

        context 'when configuration is not set (with symbols)' do
          let(:configurable_fields) { { 'foo' => { 'value' => nil } } }
          let(:configuration) { { :foo => { :value => nil } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::NEEDS_CONFIGURATION
        end

        context 'when configuration is set with symbols' do
          let(:configurable_fields) { { 'foo' => { 'value' => nil } } }
          let(:configuration) { { :foo => { :value => 'bar' } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED
        end

        context 'when configuration is set with strings' do
          let(:configurable_fields) { { 'foo' => { 'value' => nil } } }
          let(:configuration) { { 'foo' => { 'value' => 'bar' } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED
        end

        context 'when all configurable fields are set with a mix of strings and symbols' do
          let(:configurable_fields) {
            {
              'foo' => {
                'value' => 'Foo'
              },
              :bar => {
                :value => 'Bar'
              }
            }
          }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::CONFIGURED
        end

        context 'when not all configurable fields are set (with strings)' do
          let(:configurable_fields) { { 'foo' => { 'value' => nil } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::NEEDS_CONFIGURATION
        end

        context 'when not all configurable fields are set (with symbols)' do
          let(:configurable_fields) { { :foo => { :value => nil } } }

          it_behaves_like 'updates status', Connectors::ConnectorStatus::NEEDS_CONFIGURATION
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
end
