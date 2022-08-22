require 'core/heartbeat'
require 'connectors/connector_status'

describe Core::Heartbeat do
  let(:connector_id) { '123' }
  let(:service_type) { 'foo' }
  let(:connector_status) { Connectors::ConnectorStatus::CONNECTED }
  let(:connector_stored_configuration) { {} } # returned from Elasticsearch with values already specified by user
  let(:connector_default_configuration) { {} } # returned from Connector class with default values

  let(:connector_settings) { double }
  let(:connector_class) { double }
  let(:connector_instance) { double }

  let(:source_status) { { :status => 'OK' } }

  before(:each) do
    allow(Core::ConnectorSettings).to receive(:fetch).with(connector_id).and_return(connector_settings)

    allow(Core::ElasticConnectorActions).to receive(:update_connector_fields)

    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)

    allow(connector_settings).to receive(:connector_status).and_return(connector_status)
    allow(connector_settings).to receive(:connector_status_allows_sync?).and_return(true)
    allow(connector_settings).to receive(:configuration).and_return(connector_stored_configuration)

    allow(connector_class).to receive(:configurable_fields).and_return(connector_default_configuration)
    allow(connector_class).to receive(:new).and_return(connector_instance)

    allow(connector_instance).to receive(:source_status).and_return(source_status)
  end

  describe '.start_task' do
    # Just replacing threaded timer task with immediate execution to find problems immediately,
    # otherwise timer task just swallows errors
    context 'when running code synchronously just one time' do
      before(:each) do
        allow(Concurrent::TimerTask).to receive(:execute).and_yield
      end

      context 'when connector has just been created' do
        let(:connector_status) { Connectors::ConnectorStatus::CREATED }

        it 'updates stored connector service_type' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:service_type => service_type))

            described_class.start_task(connector_id, service_type)
        end

        context 'when connector has no configurable fields' do
          it 'updates connector status to CONFIGURED' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

            described_class.start_task(connector_id, service_type)
          end
        end

        context 'when connector has some configurable fields without default values' do
          let(:connector_default_configuration) do
            {
              :foo => {
                :label => 'Foo',
                :value => nil
              },
              :lala => {
                :label => 'Lala',
                :value => 'hello'
              }
            }
          end

          it 'updates connector configuration' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:configuration => connector_default_configuration))

            described_class.start_task(connector_id, service_type)
          end

          it 'updates connector status to NEEDS_CONFIGURATION' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:status => Connectors::ConnectorStatus::NEEDS_CONFIGURATION))

            described_class.start_task(connector_id, service_type)
          end
        end

        context 'when connector has all configurable fields with default values' do
          let(:connector_default_configuration) do
            {
              :foo => {
                :label => 'Foo',
                :value => 'FF'
              },
              :lala => {
                :label => 'Lala',
                :value => 'hello'
              }
            }
          end

          it 'updates connector configuration' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:configuration => connector_default_configuration))

            described_class.start_task(connector_id, service_type)
          end

          it 'updates connector status to CONFIGURED' do
            expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, hash_including(:status => Connectors::ConnectorStatus::CONFIGURED))

            described_class.start_task(connector_id, service_type)
          end
        end
      end

      context 'when connector is already connected' do
        it 'updates connector last_seen and status only' do
          expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(connector_id, { :last_seen => anything, :status => Connectors::ConnectorStatus::CONNECTED })

          described_class.start_task(connector_id, service_type)
        end
      end

      context 'when connector settings were not found' do
        let(:error) { 'something really bad happened' }

        before(:each) do
          allow(Core::ConnectorSettings).to receive(:fetch).and_raise(error)
        end

        it 'does not raise an error' do
          expect { described_class.start_task(connector_id, service_type) }.to_not raise_error
        end
      end
    end
  end
end
