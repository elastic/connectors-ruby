require 'core/jobs/producer'

describe Core::Jobs::Producer do
  describe '#enqueue_job' do
    let(:job_type) { 'unsupported_type' }
    let(:connector_settings) { double }

    context 'when the job type is unsupported' do
      it 'raise UnsupportedJobType error' do
        expect { described_class.enqueue_job(job_type: job_type, connector_settings: connector_settings) }
          .to raise_error(Core::Jobs::UnsupportedJobType)
      end
    end

    context 'when the job type is supported' do
      let(:job_type) { Core::Jobs::Producer::JOB_TYPES.first }

      context 'when connector_settings is not a kind of Core::ConnectorSettings' do
        it 'raise ArgumentError' do
          expect { described_class.enqueue_job(job_type: job_type, connector_settings: connector_settings) }
            .to raise_error(ArgumentError)
        end
      end

      context 'when connector_settings is a kind of Core::ConnectorSettings' do
        let(:fake_es_response) { {} }
        let(:fake_connector_meta) { {} }

        let(:connector_settings) { Core::ConnectorSettings.new(fake_es_response, fake_connector_meta) }
        it 'execute Core::ElasticConnectorActions.create_job' do
          allow(Core::ElasticConnectorActions).to receive(:create_job).with(connector_settings: connector_settings)

          described_class.enqueue_job(job_type: job_type, connector_settings: connector_settings)

          expect(Core::ElasticConnectorActions).to have_received(:create_job).with(connector_settings: connector_settings)
        end
      end
    end
  end
end
