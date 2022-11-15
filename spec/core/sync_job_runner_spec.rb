require 'connectors/connector_status'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'core/filtering'
require 'core/sync_job_runner'
require 'core/filtering/validation_status'
require 'utility'

describe Core::SyncJobRunner do
  let(:connector_id) { '123' }
  let(:service_type) { 'foo' }
  let(:request_pipeline) { Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE }
  let(:connector_status) { Connectors::ConnectorStatus::CONNECTED }
  let(:connector_stored_configuration) do
    # returned from Elasticsearch with values already specified by user
    {
      :lala => {
        :label => 'Lala',
        :value => 'hello'
      }
    }
  end
  let(:connector_default_configuration) do
    # returned from Connector class with default values
    {
      :lala => {
        :label => 'Lala',
        :value => nil
      }
    }
  end

  let(:connector_settings) { double }

  let(:filtering) do
    [
      {
        'domain' => Core::Filtering::DEFAULT_DOMAIN,
        'rules' => [
          Core::Filtering::SimpleRule::DEFAULT_RULE.to_h
        ],
        'advanced_snippet' => {
          'value' => {}
        }
      }
    ]
  end

  let(:connector_class) { double }
  let(:connector_instance) { double }
  let(:sink) { double }

  let(:output_index_name) { 'test-ingest-index' }
  let(:existing_document_ids) { [] } # ids of documents that are already in the index
  let(:extracted_documents) { [] } # documents returned from 3rd-party system
  let(:connector_metadata) { { :foo => 'bar' } } # metadata returned from connectors

  let(:filtering_validation_result) {
    {
      :state => Core::Filtering::ValidationStatus::VALID,
      :errors => []
    }
  }
  let(:job_id) { 'job-123' }
  let(:job_definition) do
    {
      '_id' => job_id,
      '_source' => {
        'connector' => {
          'filtering' => filtering
        }
      }
    }
  end

  let(:extract_binary_content) { true }
  let(:reduce_whitespace) { true }
  let(:run_ml_inference) { true }
  let(:total_document_count) { 100 }
  let(:ingestion_stats) do
    {
      :indexed_document_count => 0,
      :deleted_document_count => 0,
      :indexed_document_volume => 0
    }
  end

  subject { described_class.new(connector_settings) }

  before(:each) do
    allow(Core::ConnectorSettings).to receive(:fetch).with(connector_id).and_return(connector_settings)

    allow(Core::ElasticConnectorActions).to receive(:claim_job).and_return(job_definition)
    allow(Core::ElasticConnectorActions).to receive(:fetch_document_ids).and_return(existing_document_ids)
    allow(Core::ElasticConnectorActions).to receive(:complete_sync)
    allow(Core::ElasticConnectorActions).to receive(:update_connector_status)
    allow(Core::ElasticConnectorActions).to receive(:document_count).and_return(total_document_count)

    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)
    allow(Core::Ingestion::EsSink).to receive(:new).and_return(sink)
    allow(sink).to receive(:ingest)
    allow(sink).to receive(:delete)
    allow(sink).to receive(:flush)
    allow(sink).to receive(:ingestion_stats).and_return(ingestion_stats)

    allow(connector_settings).to receive(:id).and_return(connector_id)
    allow(connector_settings).to receive(:service_type).and_return(service_type)
    allow(connector_settings).to receive(:index_name).and_return(output_index_name)
    allow(connector_settings).to receive(:configuration).and_return(connector_stored_configuration)
    allow(connector_settings).to receive(:request_pipeline).and_return(request_pipeline)
    allow(connector_settings).to receive(:extract_binary_content?).and_return(extract_binary_content)
    allow(connector_settings).to receive(:reduce_whitespace?).and_return(reduce_whitespace)
    allow(connector_settings).to receive(:run_ml_inference?).and_return(run_ml_inference)
    allow(connector_settings).to receive(:filtering).and_return(filtering)

    allow(connector_class).to receive(:configurable_fields).and_return(connector_default_configuration)
    allow(connector_class).to receive(:service_type).and_return(service_type)
    allow(connector_class).to receive(:validate_filtering).and_return(filtering_validation_result)
    allow(connector_class).to receive(:new).and_return(connector_instance)

    allow(connector_instance).to receive(:metadata).and_return(connector_metadata)
    allow(connector_instance).to receive(:do_health_check!)
    allow_statement = allow(connector_instance).to receive(:yield_documents)
    extracted_documents.each { |document| allow_statement.and_yield(document) }
  end

  describe '#execute' do
    let(:ingestion_stats) { { :indexed_document_count => 1, :indexed_document_volume => 233, :deleted_document_count => 0 } }
    before(:each) do
      allow(sink).to receive(:ingestion_stats).and_return(ingestion_stats)
    end

    shared_examples_for 'sync stops with error' do
      it 'stops with error' do
        expect(Core::ElasticConnectorActions).to receive(:complete_sync) { |actual_connector_id, actual_job_id, _ingestion_stats, actual_error|
          expect(actual_connector_id).to eq(connector_id)
          expect(actual_job_id).to eq(job_id)
          expect(actual_error).to_not be_empty
        }

        subject.execute

        expect(subject.instance_variable_get(:@sync_finished)).to eq(false)
      end
    end

    shared_examples_for 'runs a full sync' do
      it 'finishes a sync job' do
        subject.execute

        expect(subject.instance_variable_get(:@sync_finished)).to eq(true)
      end
    end

    context 'when job_id is not present' do
      let(:job_id) { nil }

      it 'does not attempt to run the sync' do
        expect(Core::ElasticConnectorActions).to_not receive(:complete_sync)
        expect(Core::ElasticConnectorActions).to_not receive(:fetch_document_ids)

        expect(sink).to_not receive(:ingest)
        expect(sink).to_not receive(:delete)
        expect(sink).to_not receive(:flush)

        expect(connector_instance).to_not receive(:yield_documents)

        subject.execute
      end
    end

    context 'when filtering is in state invalid' do
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => []
        }
      }

      it_behaves_like 'sync stops with error'
    end

    context 'when filtering is in state edited' do
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::EDITED,
          :errors => []
        }
      }

      it_behaves_like 'sync stops with error'
    end

    context 'when filtering is in state valid, but errors are present' do
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::VALID,
          :errors => ['Error']
        }
      }

      it_behaves_like 'sync stops with error'
    end

    context 'when filtering is in state valid and no errors are present' do
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::VALID,
          :errors => []
        }
      }

      it_behaves_like 'runs a full sync'
    end

    context 'when connector was already configured with different configurable field set' do
      let(:connector_stored_configuration) do
        {
          :foo => {
            :label => 'Foo',
            :value => nil
          }
        }
      end

      let(:connector_default_configuration) do
        {
          :lala => {
            :label => 'Lala',
            :value => 'hello'
          }
        }
      end

      it 'raises an error' do
        expect { subject.execute }.to raise_error(Core::IncompatibleConfigurableFieldsError)
      end
    end

    it 'claims the job when starting the run' do
      expect(Core::ElasticConnectorActions).to receive(:claim_job).with(connector_id)

      subject.execute
    end

    it 'flushes the sink' do
      # We don't ingest anything, but flush still happens just in case.
      # This is done so that the last batch of documents is always ingested into the sink
      expect(sink).to receive(:flush)

      subject.execute
    end

    it_behaves_like 'runs a full sync'

    context 'when an error occurs' do
      before(:each) do
        allow(connector_instance).to receive(:do_health_check!).and_raise(StandardError.new('error message'))
      end

      it 'marks the sync as unfinished without overriding the error message with the thread error message' do
        subject.execute

        expect(subject.instance_variable_get(:@sync_finished)).to eq(false)
        expect(subject.instance_variable_get(:@sync_error)).to eq('error message')
      end
    end

    context 'when validation thread did not finish execution' do
      before(:each) do
        # Exception, which is not rescued (treated like something, which stopped the sync thread)
        allow(connector_instance).to receive(:do_health_check!).and_raise(Exception.new('Oh no!'))
      end

      it 'sets an error, that the validation thread was killed' do
        # Check for exception thrown on purpose, so that the test is not marked as failed for the wrong reason
        expect { subject.execute }.to raise_exception

        expect(subject.instance_variable_get(:@sync_finished)).to eq(false)
        expect(subject.instance_variable_get(:@sync_error)).to eq('Sync thread didn\'t finish execution. Check connector logs for more details.')
      end
    end

    context 'when validation thread did not finish execution' do
      before(:each) do
        # Exception, which is not rescued (treated like something, which stopped the sync thread)
        allow(connector_instance).to receive(:do_health_check!).and_raise(Exception.new('Oh no!'))
      end

      it 'sets an error, that the validation thread was killed' do
        # Check for exception thrown on purpose, so that the test is not marked as failed for the wrong reason
        expect { subject.execute }.to raise_exception

        expect(subject.instance_variable_get(:@sync_finished)).to eq(false)
        expect(subject.instance_variable_get(:@sync_error)).to eq('Sync thread didn\'t finish execution. Check connector logs for more details.')
      end
    end

    context 'when a bunch of documents are returned from 3rd-party system' do
      let(:doc1) do
        {
          :id => 1,
          :title => 'Hello',
          :body => 'World'
        }
      end

      let(:doc2) do
        {
          :id => 2,
          :title => 'thanks',
          :body => 'for the fish'
        }
      end

      let(:extracted_documents) { [doc1, doc2] } # documents returned from 3rd-party system

      it 'ingests returned documents into the sink' do
        expect(sink).to receive(:ingest).with(doc1)
        expect(sink).to receive(:ingest).with(doc2)

        subject.execute
      end

      context 'with filtering rules' do
        let(:additional_rules) do
          [
            Core::Filtering::SimpleRule.from_args('1', 'exclude', 'title', 'equals', 'Hello').to_h
          ]
        end
        before(:each) do
          filtering[0]['rules'].unshift(*additional_rules)
        end

        it 'does not ingest the excluded document' do
          expect(sink).to_not receive(:ingest).with(doc1)
          expect(sink).to receive(:ingest).with(doc2)

          subject.execute
        end

        context 'with non-matching rule' do
          let(:additional_rules) do
            [
              Core::Filtering::SimpleRule.from_args('1', 'exclude', 'foo', 'equals', 'Hello').to_h
            ]
          end

          it 'indexes all docs' do
            expect(sink).to receive(:ingest).with(doc1)
            expect(sink).to receive(:ingest).with(doc2)

            subject.execute
          end
        end
      end

      context 'when some documents were present before' do
        let(:existing_document_ids) { [3, 4, 'lala', 'some other id'] }
        let(:ingestion_stats) do
          {
            :indexed_document_count => 15,
            :deleted_document_count => 10,
            :indexed_document_volume => 1241251
          }
        end

        it 'attempts to remove existing documents' do
          existing_document_ids.each do |id|
            expect(sink).to receive(:delete).with(id)
          end

          subject.execute
        end

        it 'marks the job as complete' do
          expected_error = nil

          expect(Core::ElasticConnectorActions).to receive(:complete_sync).with(connector_id, job_id, anything, expected_error)

          subject.execute
        end

        it 'updates job stats' do
          expect(Core::ElasticConnectorActions).to receive(:complete_sync).with(connector_id, job_id, hash_including(ingestion_stats), nil)

          subject.execute
        end

        context 'when an error happens during sync' do
          let(:error_message) { 'whoops' }
          before(:each) do
            allow(sink).to receive(:flush).and_raise('whoops')
          end

          it 'marks the job as complete with proper error' do
            expect(Core::ElasticConnectorActions).to receive(:complete_sync).with(connector_id, job_id, anything, error_message)

            subject.execute
          end

          it 'updates job stats' do
            expect(Core::ElasticConnectorActions).to receive(:complete_sync).with(connector_id, job_id, hash_including(ingestion_stats), anything)

            subject.execute
          end
        end
      end
    end
  end

  context 'ingest metadata' do
    let(:document) { { 'body' => 'hello, world' } }

    it 'augments document data' do
      subject.send(:add_ingest_metadata, document)
      expect(document['_extract_binary_content']).to be
      expect(document['_reduce_whitespace']).to be
      expect(document['_run_ml_inference']).to be
    end

    context 'when the settings are false' do
      let(:extract_binary_content) { false }
      let(:reduce_whitespace) { false }
      let(:run_ml_inference) { false }

      it 'does not augment data' do
        subject.send(:add_ingest_metadata, document)
        expect(document['_extract_binary_content']).to_not be
        expect(document['_reduce_whitespace']).to_not be
        expect(document['_run_ml_inference']).to_not be
      end
    end
  end
end
