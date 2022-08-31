require 'core/elastic_connector_actions'
require 'connectors/connector_status'
require 'connectors/sync_status'
require 'utility/es_client'

describe Core::ElasticConnectorActions do
  let(:connector_id) { 'one-two-three' }
  let(:es_client) { double }
  let(:es_client_indices_api) { double }
  let(:connectors_index) { Core::ElasticConnectorActions::CONNECTORS_INDEX }
  let(:jobs_index) { Core::ElasticConnectorActions::JOB_INDEX }

  before(:each) do
    allow(Utility::EsClient).to receive(:new).and_return(es_client)

    allow(es_client).to receive(:get)
    allow(es_client).to receive(:update)
    allow(es_client).to receive(:index)
    allow(es_client).to receive(:search)
    allow(es_client).to receive(:indices).and_return(es_client_indices_api)
    allow(es_client).to receive(:open_point_in_time)
    allow(es_client).to receive(:close_point_in_time)

    allow(es_client_indices_api).to receive(:exists?).and_return(true)
    allow(es_client_indices_api).to receive(:get_mapping).and_return({})
    allow(es_client_indices_api).to receive(:put_mapping)
    allow(es_client_indices_api).to receive(:create)

    Core::ElasticConnectorActions.instance_variable_set(:@client, nil)
  end

  context '#force_sync' do
    it 'updates sync_now flag' do
      # { :body => { :doc => { :sync_now => true } } }
      expect(es_client).to receive(:update).with(
        hash_including(
          :body => hash_including(
            :doc => hash_including(
              :sync_now => true
            )
          )
        )
      )

      described_class.force_sync(connector_id)
    end

    it 'enables sync' do
      # { :body => { :doc => { :scheduling => { :enabled => true } } } }
      expect(es_client).to receive(:update).with(
        hash_including(
          :body => hash_including(
            :doc => hash_including(
              :scheduling => hash_including(
                :enabled => true
              )
            )
          )
        )
      )

      described_class.force_sync(connector_id)
    end
  end

  context '#create_connector' do
    let(:data_index_name) { 'some-data-index-v1-23' }
    let(:service_type) { 'some-service-type' }
    let(:created_connector_id) { 'just-created-this-connector-id-1' }

    before(:each) do
      allow(es_client).to receive(:index).with(:index => connectors_index, :body => anything).and_return({
        '_id' => created_connector_id
      })
    end

    it 'sends a index request with proper index_name and service_type' do
      expect(es_client).to receive(:index).with(
        :index => connectors_index,
        :body => hash_including(
          :index_name => data_index_name,
          :service_type => service_type
        )
      )

      described_class.create_connector(data_index_name, service_type)
    end

    it 'enables scheduling immediately' do
      expect(es_client).to receive(:index).with(
        :index => connectors_index,
        :body => hash_including(
          :scheduling => {
            :enabled => true
          }
        )
      )

      described_class.create_connector(data_index_name, service_type)
    end

    it 'returns id of created record' do
      id = described_class.create_connector(data_index_name, service_type)
      expect(id).to eq(created_connector_id)
    end
  end

  context '#get_connector' do
    before(:each) do
      allow(es_client).to receive(:get).and_return({ '_id' => '123', 'something' => 'something' })
    end

    it 'sends a get request with correct index and id' do
      expect(es_client).to receive(:get).with(
        hash_including(
          :index => connectors_index,
          :id => connector_id
        )
      )

      described_class.get_connector(connector_id)
    end

    it 'sends a get request that ignores 404s' do
      expect(es_client).to receive(:get).with(
        hash_including(
          :ignore => 404
        )
      )

      described_class.get_connector(connector_id)
    end

    it 'transforms response hash keys to symbols' do
      connector = described_class.get_connector(connector_id)

      expect(connector).to have_key(:_id)
      expect(connector).to have_key(:something)
    end
  end

  context '#update_connector_configuration' do
    let(:doc) do
      {
        :schedule => { :enabled => false },
        :last_seen => Time.now
      }
    end

    it 'sends an update request' do
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => { :doc => { :configuration => doc } }
      )

      described_class.update_connector_configuration(connector_id, doc)
    end
  end

  context '#enable_connector_scheduling' do
    let(:cron_expression) { '0 * * * * *' }

    it 'updates connector scheduling.enabled to true' do
      # { :body => { :doc => { :scheduling => { :enabled => true, :something => something} } } }
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => hash_including(
            :scheduling => hash_including(
              :enabled => true
            )
          )
        }
      )

      described_class.enable_connector_scheduling(connector_id, cron_expression)
    end

    it 'updates connector scheduling interval' do
      # { :body => { :doc => { :scheduling => { :interval => '<cron_interval>', :something => something} } } }
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => hash_including(
            :scheduling => hash_including(
              :interval => cron_expression
            )
          )
        }
      )

      described_class.enable_connector_scheduling(connector_id, cron_expression)
    end
  end

  context '#disable_connector_scheduling' do
    it 'updates connector scheduling.enabled to false' do
      # { :body => { :doc => { :scheduling => { :enabled => true, :something => something} } } }
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => hash_including(
            :scheduling => hash_including(
              :enabled => false
            )
          )
        }
      )

      described_class.disable_connector_scheduling(connector_id)
    end
  end

  context '#set_configurable_field' do
    let(:field_name) { 'api_key' }
    let(:field_label) { 'API Key' }
    let(:field_value) { 'super secret one!' }

    it 'sends an update request for configurable field' do
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => {
            :configuration => {
              field_name => {
                :label => field_label,
                :value => field_value
              }
            }
          }
        }
      )

      described_class.set_configurable_field(connector_id, field_name, field_label, field_value)
    end
  end

  context '#claim_job' do
    before(:each) do
      allow(es_client).to receive(:index).with(:index => jobs_index, :body => anything).and_return({ '_id' => 'job-123' })
    end

    it 'updates connector status fields' do
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => hash_including(
            :last_synced,
            :sync_now => false,
            :last_sync_status => Connectors::SyncStatus::IN_PROGRESS
          )
        }
      )

      described_class.claim_job(connector_id)
    end

    it 'creates a record in jobs index' do
      expect(es_client).to receive(:index).with(
        :index => jobs_index,
        :body => hash_including(
          :worker_hostname,
          :created_at,
          :connector_id => connector_id,
          :status => Connectors::SyncStatus::IN_PROGRESS
        )
      )

      described_class.claim_job(connector_id)
    end
  end

  context '#update_connector_status' do
    let(:status) { Connectors::ConnectorStatus::CONFIGURED }

    it 'sends update request with expected body' do
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => { :status => status }
        }
      )

      described_class.update_connector_status(connector_id, status)
    end
  end

  context '#complete_sync' do
    let(:job_id) { 'completed-job-1' }
    let(:status) { {} }

    it 'updates last connector sync status, sync time and counts' do
      expect(es_client).to receive(:update).with(
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => hash_including(
            :last_synced,
            :last_indexed_count,
            :last_deleted_count,
            :last_sync_status => Connectors::SyncStatus::COMPLETED
          )
        }
      )

      described_class.complete_sync(connector_id, job_id, status)
    end

    it 'updates the record in jobs index' do
      expect(es_client).to receive(:update).with(
        :index => jobs_index,
        :id => job_id,
        :body => {
          :doc => hash_including(
            :completed_at,
            :indexed_document_count,
            :deleted_document_count,
            :status => Connectors::SyncStatus::COMPLETED
          )
        }
      )

      described_class.complete_sync(connector_id, job_id, status)
    end

    context 'when status contains an error' do
      let(:error_message) { 'something really went wrong' }
      let(:status) { { :error => error_message } }

      it 'updates last connector sync status to error' do
        expect(es_client).to receive(:update).with(
          :index => connectors_index,
          :id => connector_id,
          :body => {
            :doc => hash_including(
              :last_synced,
              :last_indexed_count,
              :last_deleted_count,
              :last_sync_status => Connectors::SyncStatus::FAILED,
              :last_sync_error => status[:error]
            )
          }
        )

        described_class.complete_sync(connector_id, job_id, status)
      end
    end
  end

  context '#fetch_document_ids' do
    let(:data_index_name) { 'some-data-index' }
    let(:pit_id) { 'bottomless-pit' }
    let(:first_page_ids) { (1..1000).to_a }
    let(:second_page_ids) { (1001..2000).to_a }
    let(:third_page_ids) { (2001..3000).to_a }

    def sort_field_from_id(id)
      "sort-#{id}"
    end

    def ids_page(ids)
      {
        'hits' => {
          'hits' => ids.map do |i|
            {
              '_id' => i,
              'sort' => sort_field_from_id(i)
            }
          end
        },
        'pit_id' => pit_id
      }
    end

    before(:each) do
      allow(es_client).to receive(:open_point_in_time).and_return({ 'id' => pit_id })
      allow(es_client).to receive(:close_point_in_time)
      allow(es_client).to receive(:search).with(
        {
          :body => hash_including(
            :query => hash_excluding(:search_after)
          )
        }
      ).and_return(ids_page(first_page_ids))

      allow(es_client).to receive(:search).with(
        {
          :body => hash_including(:search_after => sort_field_from_id(first_page_ids.last))
        }
      ).and_return(ids_page(second_page_ids))

      allow(es_client).to receive(:search).with(
        {
          :body => hash_including(:search_after => sort_field_from_id(second_page_ids.last))
        }
      ).and_return(ids_page(third_page_ids))

      allow(es_client).to receive(:search).with(
        {
          :body => hash_including(:search_after => sort_field_from_id(third_page_ids.last))
        }
      ).and_return(ids_page([]))
    end

    it 'manages a point in time' do
      expect(es_client).to receive(:open_point_in_time).with(
        hash_including(
          :index => data_index_name
        )
      )

      expect(es_client).to receive(:close_point_in_time).with({ :index => data_index_name, :body => { :id => pit_id } })

      described_class.fetch_document_ids(data_index_name)
    end

    it 'fetches all expected id' do
      ids = described_class.fetch_document_ids(data_index_name)

      expect(ids).to include(*first_page_ids)
      expect(ids).to include(*second_page_ids)
      expect(ids).to include(*third_page_ids)
    end

    context 'when third page is smaller than query page size' do
      let(:third_page_ids) { (2001..2500).to_a }

      it 'does not send fourth request' do
        expect(es_client).to receive(:search).exactly(3).times

        described_class.fetch_document_ids(data_index_name)
      end
    end
  end

  context '#ensure_index_exists' do
    let(:data_index_name) { 'was-i-created-or-not' }
    let(:index_mappings) { {}  }
    let(:index_exists) { false }
    let(:existing_index_mappings) { {} }

    before(:each) do
      allow(es_client_indices_api).to receive(:exists?).and_return(index_exists)
      allow(es_client_indices_api).to receive(:get_mapping).and_return({ data_index_name => { 'mappings' => existing_index_mappings } })
      allow(es_client_indices_api).to receive(:put_mapping)
      allow(es_client_indices_api).to receive(:create)
    end

    context 'when index does not exist' do
      let(:index_exists) { false }

      it 'attempts to create an index' do
        expect(es_client_indices_api).to receive(:create).with(:index => data_index_name, :body => anything)

        described_class.ensure_index_exists(data_index_name)
      end
    end

    context 'when index exists' do
      let(:index_exists) { true }

      it 'does not attempt to create an index' do
        expect(es_client_indices_api).to_not receive(:create)

        described_class.ensure_index_exists(data_index_name)
      end

      context 'when no mappings are set up for the index' do
        let(:existing_index_mappings) { {} }

        context 'when no mappings are passed into the method' do
          it 'does not attempt to create index mappings' do
            expect(es_client_indices_api).to_not receive(:put_mapping)

            described_class.ensure_index_exists(data_index_name)
          end
        end

        context 'when mappings are passed into the method' do
          it 'attempts to put mappings for the index' do
            expect(es_client_indices_api).to receive(:put_mapping)

            described_class.ensure_index_exists(data_index_name, { :mappings => { :something => :something } })
          end
        end
      end

      context 'when mappings are already present for the index' do
        let(:existing_index_mappings) { { :something => 'something' } }

        it 'does not attempt to change mappings' do
          expect(es_client_indices_api).to_not receive(:put_mapping)

          described_class.ensure_index_exists(data_index_name, { :mappings => { :something => :different } })
        end
      end
    end
  end

  context '#ensure_content_index_exists' do
    let(:index_name) { 'some-cool-index' }
    let(:use_icu_locale) { true }
    let(:language_code) { 'it-IT' }

    let(:settings) { { :hey => 'its settings' } }
    let(:mappings) { { :whatsup => 'its mappings' } }

    before(:each) do
      allow(Utility::Elasticsearch::Index::TextAnalysisSettings).to receive(:new).with(:language_code => language_code, :analysis_icu => use_icu_locale).and_return(settings)
      allow(Utility::Elasticsearch::Index::Mappings).to receive(:default_text_fields_mappings).with(:connectors_index => true).and_return(mappings)
    end

    it 'calls ensure_index_exists with expected parameters' do
      expect(described_class).to receive(:ensure_index_exists).with(index_name, { :settings => settings, :mappings => mappings })

      described_class.ensure_content_index_exists(index_name, use_icu_locale, language_code)
    end
  end

  context '#ensure_connectors_index_exists' do
    it 'creates connectors index with expected alias' do
      expect(described_class).to receive(:ensure_index_exists).with("#{connectors_index}-v1", hash_including(:aliases => hash_including(connectors_index), :mappings => anything))

      described_class.ensure_connectors_index_exists
    end
  end

  context '#ensure_job_index_exists' do
    it 'creates connector jobs index with expected alias' do
      expect(described_class).to receive(:ensure_index_exists).with("#{jobs_index}-v1", hash_including(:aliases => hash_including(jobs_index), :mappings => anything))

      described_class.ensure_job_index_exists
    end
  end

  context '#update_connector_fields' do
    let(:doc) { {} }

    context 'when no doc is passed' do
      it 'does no elasticsearch calls' do
        expect(es_client).to_not receive(:update)

        described_class.update_connector_fields(connector_id, doc)
      end
    end

    context 'when a doc is passed' do
      let(:doc) { { :something => :something } }

      it 'does expected elastic index request' do
        expect(es_client).to receive(:update).with(:index => connectors_index, :id => connector_id, :body => { :doc => doc })

        described_class.update_connector_fields(connector_id, doc)
      end
    end
  end
end
