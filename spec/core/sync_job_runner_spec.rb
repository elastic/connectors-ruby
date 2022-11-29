require 'connectors/connector_status'
require 'connectors/sync_status'
require 'core'
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

  let(:job) { double }
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
  let(:connector_running) { false }
  let(:job_id) { 'job-123' }
  let(:job_canceling) { false }
  let(:job_in_progress) { true }
  let(:error_message) { nil }

  let(:extract_binary_content) { true }
  let(:reduce_whitespace) { true }
  let(:run_ml_inference) { true }
  let(:total_document_count) { 100 }
  let(:ingestion_stats) do
    {
      :indexed_document_count => 12,
      :deleted_document_count => 234,
      :indexed_document_volume => 0
    }
  end

  let(:max_ingestion_queue_size) { 123 }
  let(:max_ingestion_queue_bytes) { 123456789 }

  subject { described_class.new(connector_settings, job, max_ingestion_queue_size, max_ingestion_queue_bytes) }

  before(:each) do
    allow(Core::ConnectorSettings).to receive(:fetch_by_id).with(connector_id).and_return(connector_settings)

    allow(Core::ConnectorJob).to receive(:fetch_by_id).with(job_id).and_return(job)
    allow(job).to receive(:id).and_return(job_id)
    allow(job).to receive(:make_running!)
    allow(job).to receive(:filtering).and_return(filtering)
    allow(job).to receive(:update_metadata)
    allow(job).to receive(:done!)
    allow(job).to receive(:cancel!)
    allow(job).to receive(:error!)
    allow(job).to receive(:canceling?).and_return(job_canceling)
    allow(job).to receive(:in_progress?).and_return(job_in_progress)
    allow(job).to receive(:index_name).and_return(output_index_name)
    allow(job).to receive(:service_type).and_return(service_type)
    allow(job).to receive(:extract_binary_content?).and_return(extract_binary_content)
    allow(job).to receive(:reduce_whitespace?).and_return(reduce_whitespace)
    allow(job).to receive(:run_ml_inference?).and_return(run_ml_inference)
    allow(job).to receive(:configuration).and_return(connector_stored_configuration)

    allow(Core::ElasticConnectorActions).to receive(:fetch_document_ids).and_return(existing_document_ids)
    allow(Core::ElasticConnectorActions).to receive(:update_connector_status)
    allow(Core::ElasticConnectorActions).to receive(:update_connector_last_sync_status)

    allow(Connectors::REGISTRY).to receive(:connector_class).and_return(connector_class)
    allow(Core::Ingestion::EsSink).to receive(:new).and_return(sink)
    allow(sink).to receive(:ingest)
    allow(sink).to receive(:delete)
    allow(sink).to receive(:flush)
    allow(sink).to receive(:ingestion_stats).and_return(ingestion_stats)

    allow(connector_settings).to receive(:id).and_return(connector_id)
    allow(connector_settings).to receive(:configuration).and_return(connector_stored_configuration)
    allow(connector_settings).to receive(:request_pipeline).and_return(request_pipeline)
    allow(connector_settings).to receive(:running?).and_return(connector_running)
    allow(connector_settings).to receive(:update_last_sync!)

    allow(connector_class).to receive(:configurable_fields).and_return(connector_default_configuration)
    allow(connector_class).to receive(:validate_filtering).and_return(filtering_validation_result)
    allow(connector_class).to receive(:new).and_return(connector_instance)

    allow(connector_instance).to receive(:metadata).and_return(connector_metadata)
    allow(connector_instance).to receive(:do_health_check!)
    allow_statement = allow(connector_instance).to receive(:yield_documents)
    extracted_documents.each { |document| allow_statement.and_yield(document) }

    # set to a large number to skip job check
    stub_const("#{described_class}::JOB_REPORTING_INTERVAL", 10000)
  end

  describe '#new' do
    let(:bulk_queue) { double }

    before(:each) do
      allow(Utility::BulkQueue).to receive(:new).and_return(bulk_queue)
    end

    it 'passes max_ingestion_queue_size and max_ingestion_queue_bytes to ingestion classes' do
      expect(Utility::BulkQueue).to receive(:new)
        .with(max_ingestion_queue_size, max_ingestion_queue_bytes)

      expect(Core::Ingestion::EsSink).to receive(:new)
        .with(anything, anything, bulk_queue, max_ingestion_queue_bytes)

      described_class.new(connector_settings, job, max_ingestion_queue_size, max_ingestion_queue_bytes)
    end
  end

  describe '#execute' do
    shared_examples_for 'claims the job' do
      it '' do
        expect(Core::ElasticConnectorActions).to receive(:update_connector_last_sync_status)
        expect(job).to receive(:make_running!)

        subject.execute
      end
    end

    shared_examples_for 'does not run a sync' do
      it '' do
        expect(job).to_not receive(:done!)
        expect(job).to_not receive(:cancel!)
        expect(job).to_not receive(:error!)
        expect(connector_settings).to_not receive(:update_last_sync!).with(job)

        subject.execute
      end
    end

    shared_examples_for 'sync stops with error' do
      it 'stops with error' do
        expect(job).to receive(:error!).with(error_message, ingestion_stats, connector_metadata)
        expect(connector_settings).to receive(:update_last_sync!).with(job)

        subject.execute
      end
    end

    shared_examples_for 'runs a full sync' do
      it 'finishes a sync job' do
        expect(job).to receive(:done!).with(ingestion_stats, connector_metadata)
        expect(connector_settings).to receive(:update_last_sync!).with(job)

        subject.execute
      end
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

    context 'when connector is running' do
      let(:connector_running) { true }

      it_behaves_like 'does not run a sync'
    end

    context 'when failing to make connector running' do
      before(:each) do
        allow(Core::ElasticConnectorActions).to receive(:update_connector_last_sync_status).and_raise(StandardError)
      end

      it_behaves_like 'does not run a sync'
    end

    context 'when failing to make job running' do
      before(:each) do
        allow(job).to receive(:make_running!).and_raise(StandardError)
      end

      it_behaves_like 'does not run a sync'
    end

    context 'when filtering is in state invalid' do
      let(:error_message) { "Active filtering is not in valid state (current state: #{filtering_validation_result[:state]}) for connector #{connector_id}. Please check active filtering in connectors index." }
      let(:connector_metadata) { nil }
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::INVALID,
          :errors => []
        }
      }

      it_behaves_like 'sync stops with error'
    end

    context 'when filtering is in state edited' do
      let(:error_message) { "Active filtering is not in valid state (current state: #{filtering_validation_result[:state]}) for connector #{connector_id}. Please check active filtering in connectors index." }
      let(:connector_metadata) { nil }
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::EDITED,
          :errors => []
        }
      }

      it_behaves_like 'sync stops with error'
    end

    context 'when filtering is in state valid, but errors are present' do
      let(:error_message) { "Active filtering is in valid state, but errors were detected (errors: #{filtering_validation_result[:errors]}) for connector #{connector_id}. Please check active filtering in connectors index." }
      let(:connector_metadata) { nil }
      let(:filtering_validation_result) {
        {
          :state => Core::Filtering::ValidationStatus::VALID,
          :errors => ['Error']
        }
      }

      it_behaves_like 'sync stops with error'
    end

    it_behaves_like 'claims the job'

    it 'flushes the sink' do
      # We don't ingest anything, but flush still happens just in case.
      # This is done so that the last batch of documents is always ingested into the sink
      expect(sink).to receive(:flush)

      subject.execute
    end

    it_behaves_like 'runs a full sync'

    context 'when an error occurs' do
      let(:error_message) { 'error message' }
      before(:each) do
        allow(connector_instance).to receive(:do_health_check!).and_raise(StandardError.new(error_message))
      end

      it_behaves_like 'sync stops with error'
    end

    context 'when validation thread did not finish execution' do
      let(:error_message) { 'Sync thread didn\'t finish execution. Check connector logs for more details.' }
      before(:each) do
        # Exception, which is not rescued (treated like something, which stopped the sync thread)
        allow(connector_instance).to receive(:do_health_check!).and_raise(Exception.new('Oh no!'))
      end

      it 'sets an error, that the validation thread was killed' do
        # Check for exception thrown on purpose, so that the test is not marked as failed for the wrong reason
        expect { subject.execute }.to raise_exception

        expect(subject.instance_variable_get(:@sync_status)).to eq(Connectors::SyncStatus::ERROR)
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

        it 'attempts to remove existing documents' do
          existing_document_ids.each do |id|
            expect(sink).to receive(:delete).with(id)
          end

          subject.execute
        end

        it_behaves_like 'runs a full sync'

        context 'when an error happens during sync' do
          let(:error_message) { 'whoops' }
          before(:each) do
            allow(sink).to receive(:flush).and_raise('whoops')
          end

          it_behaves_like 'sync stops with error'
        end
      end

      context 'with reporting' do
        before(:each) do
          # it will check job and report metadata for every document
          stub_const("#{described_class}::JOB_REPORTING_INTERVAL", 0)
        end

        it 'reports metadata' do
          expect(job).to receive(:update_metadata).with(ingestion_stats, connector_metadata)

          subject.execute
        end

        context 'when connector is deleted' do
          before(:each) do
            allow(Core::ConnectorSettings).to receive(:fetch_by_id).and_return(nil)
          end

          it 'marks the job as error' do
            expect(job).to receive(:error!).with(Core::ConnectorNotFoundError.new(connector_id).message, ingestion_stats, connector_metadata)

            subject.execute
          end
        end

        context 'when job is deleted' do
          before(:each) do
            allow(Core::ConnectorJob).to receive(:fetch_by_id).and_return(nil)
          end

          it 'updates connector' do
            expect(connector_settings).to receive(:update_last_sync!)

            subject.execute
          end
        end

        context 'when job is canceled' do
          let(:job_canceling) { true }

          it 'cancels the job' do
            expect(job).to receive(:cancel!).with(ingestion_stats, connector_metadata)
            expect(connector_settings).to receive(:update_last_sync!)

            subject.execute
          end
        end

        context 'when job is not in_progress' do
          let(:job_in_progress) { false }
          let(:job_status) { Connectors::SyncStatus::COMPLETED }

          before(:each) do
            allow(job).to receive(:status).and_return(job_status)
          end

          it 'marks the job error' do
            expect(job).to receive(:error!).with(Core::ConnectorJobNotRunningError.new(job_id, job_status).message, ingestion_stats, connector_metadata)
            expect(connector_settings).to receive(:update_last_sync!)

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
