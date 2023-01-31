require 'core'
require 'connectors/connector_status'
require 'connectors/sync_status'
require 'utility'

def filter_validation_result(domain, state, errors)
  {
    :domain => domain,
    :draft => {
      :validation => {
        :state => state,
        :errors => errors
      }
    }
  }
end

describe Core::ElasticConnectorActions do
  let(:connector_id) { 'one-two-three' }
  let(:connector) { double }
  let(:job_id) { 'some-job-id' }
  let(:es_client) { double }
  let(:es_client_indices_api) { double }
  let(:connectors_index) { Utility::Constants::CONNECTORS_INDEX }
  let(:jobs_index) { Utility::Constants::JOB_INDEX }

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

  describe '#force_sync' do
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

  describe '#create_connector' do
    let(:data_index_name) { 'some-data-index-v1-23' }
    let(:service_type) { 'some-service-type' }
    let(:created_connector_id) { 'just-created-this-connector-id-1' }

    before(:each) do
      allow(es_client)
        .to receive(:index)
        .with(:index => connectors_index, :body => anything)
        .and_return(
          {
            '_id' => created_connector_id
          }
        )
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

  describe '#get_connector' do
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

  describe '#connectors_meta' do
    before(:each) do
      allow(es_client_indices_api)
        .to receive(:get_mapping)
        .and_return({ "#{Utility::Constants::CONNECTORS_INDEX}-v1" => { 'mappings' => { '_meta' => { 'version' => '1' }, 'properties' => { 'api_key_id' => { 'type' => 'keyword' }, 'configuration' => { 'type' => 'object' }, 'error' => { 'type' => 'keyword' }, 'index_name' => { 'type' => 'keyword' }, 'language' => { 'type' => 'keyword' }, 'last_seen' => { 'type' => 'date' }, 'last_sync_error' => { 'type' => 'keyword' }, 'last_sync_status' => { 'type' => 'keyword' }, 'last_synced' => { 'type' => 'date' }, 'name' => { 'type' => 'keyword' }, 'scheduling' => { 'properties' => { 'enabled' => { 'type' => 'boolean' }, 'interval' => { 'type' => 'text' } } }, 'service_type' => { 'type' => 'keyword' }, 'status' => { 'type' => 'keyword' }, 'sync_now' => { 'type' => 'boolean' } } } } })
    end

    it 'gets the meta' do
      expect(described_class.connectors_meta).to eq({ 'version' => '1' })
    end
  end

  describe '#search_connectors' do
    let(:connector_one) { { '_id' => '123', '_source' => { 'something' => 'something', 'is_native' => true } }.with_indifferent_access }
    let(:connector_two) { { '_id' => '456', '_source' => { 'something' => 'something', 'is_native' => true } }.with_indifferent_access }
    let(:query) { { :term => { :is_native => true } } }
    let(:offset) { 0 }
    let(:page_size) { 10 }
    before(:each) do
      allow(es_client).to receive(:search).and_return({ 'hits' => { 'hits' => [connector_one, connector_two], 'total' => { 'value' => 2 } } })
    end
    it 'returns all native connectors' do
      connectors = described_class.search_connectors(query, page_size, offset)
      expect(connectors['hits']['hits'].size).to eq(2)
      expect(connectors['hits']['hits'][0]['_id']).to eq(connector_one['_id'])
      expect(connectors['hits']['hits'][1]['_id']).to eq(connector_two['_id'])
    end
  end

  describe '.update_connector_configuration' do
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
        :body => { :doc => { :configuration => doc } },
        :refresh => true,
        :retry_on_conflict => 3
      )

      described_class.update_connector_configuration(connector_id, doc)
    end
  end

  describe '#enable_connector_scheduling' do
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
        },
        :refresh => true,
        :retry_on_conflict => 3
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
        },
        :refresh => true,
        :retry_on_conflict => 3
      )

      described_class.enable_connector_scheduling(connector_id, cron_expression)
    end
  end

  describe '#disable_connector_scheduling' do
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
        },
        :refresh => true,
        :retry_on_conflict => 3
      )

      described_class.disable_connector_scheduling(connector_id)
    end
  end

  describe '#set_configurable_field' do
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
        },
        :refresh => true,
        :retry_on_conflict => 3
      )

      described_class.set_configurable_field(connector_id, field_name, field_label, field_value)
    end
  end

  describe '#update_filtering_validation' do
    let(:current_filtering) {
      []
    }

    let(:new_validation_states) {
      {}
    }

    let(:expected_filtering_update) {
      []
    }

    before(:each) do
      allow(connector).to receive(:dig).with(:_source, :filtering).and_return(current_filtering)
      allow(described_class).to receive(:get_connector).with(connector_id).and_return(connector)
    end

    shared_examples_for 'does not update any validation result' do
      it 'does not update' do
        expect(es_client).to_not receive(:update).with(anything)

        described_class.update_filtering_validation(connector_id, new_validation_states)
      end
    end

    shared_examples_for 'updates domain validation results' do
      it 'updates result' do
        expect(es_client).to receive(:update).with(
          :index => connectors_index,
          :id => connector_id,
          :body => {
            :doc => hash_including(
              :filtering => expected_filtering_update
            )
          },
          :refresh => true,
          :retry_on_conflict => 3
        )

        described_class.update_filtering_validation(connector_id, new_validation_states)
      end
    end

    context 'filtering contains an array with multiple domains, only one should be updated' do
      let(:current_filtering) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::EDITED, []),
          filter_validation_result('domain-two', Core::Filtering::ValidationStatus::EDITED, []),
          filter_validation_result('domain-three', Core::Filtering::ValidationStatus::EDITED, []),
        ]
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::VALID,
            :errors => []
          }
        }
      }

      let(:expected_filtering_update) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::VALID, []),
          filter_validation_result('domain-two', Core::Filtering::ValidationStatus::EDITED, []),
          filter_validation_result('domain-three', Core::Filtering::ValidationStatus::EDITED, []),
        ]
      }

      it_behaves_like 'updates domain validation results'
    end

    context 'filtering contains an array with multiple domains, two should be updated' do
      let(:current_filtering) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::EDITED, []),
          filter_validation_result('domain-two', Core::Filtering::ValidationStatus::EDITED, []),
          filter_validation_result('domain-three', Core::Filtering::ValidationStatus::EDITED, []),
        ]
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['some error']
              }
            ]
          },
          'domain-two' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['another-error-id'],
                :messages => ['another error']
              },
              {
                :ids => ['and-another-error-id'],
                :messages => ['and another error']
              }
            ]
          }
        }
      }

      let(:expected_filtering_update) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::INVALID, [
            {
              :ids => ['error-id'],
              :messages => ['some error']
            }
          ]),
          filter_validation_result('domain-two', Core::Filtering::ValidationStatus::INVALID, [
            {
              :ids => ['another-error-id'],
              :messages => ['another error']
            },
            {
              :ids => ['and-another-error-id'],
              :messages => ['and another error']
            }
          ]),
          filter_validation_result('domain-three', Core::Filtering::ValidationStatus::EDITED, []),
        ]
      }

      it_behaves_like 'updates domain validation results'
    end

    context 'filtering is an object' do
      let(:current_filtering) {
        filter_validation_result('domain-one', Core::Filtering::ValidationStatus::EDITED, [])
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::VALID,
            :errors => []
          }
        }
      }

      let(:expected_filtering_update) {
        filter_validation_result('domain-one', Core::Filtering::ValidationStatus::VALID, [])
      }

      it_behaves_like 'updates domain validation results'
    end

    context 'filtering contains an array with only one object' do
      let(:current_filtering) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::EDITED, [])
        ]
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      let(:expected_filtering_update) {
        [
          filter_validation_result('domain-one', Core::Filtering::ValidationStatus::INVALID, [
            {
              :ids => ['error-id'],
              :messages => ['error']
            }
          ])
        ]
      }

      it_behaves_like 'updates domain validation results'
    end

    context 'filtering contains an array with multiple domains, but not the one to update' do
      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      it_behaves_like 'does not update any validation result'
    end

    context 'filtering contains an empty array' do
      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      it_behaves_like 'does not update any validation result'
    end

    context 'filtering contains an empty object' do
      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      it_behaves_like 'does not update any validation result'
    end

    context 'new validations states are empty' do
      let(:new_validation_states) {
        {}
      }

      it_behaves_like 'does not update any validation result'
    end

    context 'ES filtering mapping is incorrect' do
      let(:current_filtering) {
        'wrong format'
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      it_behaves_like 'does not update any validation result'

      it 'also logs a warning' do
        expect(Utility::Logger).to receive(:warn).with(anything)

        described_class.update_filtering_validation(connector_id, new_validation_states)
      end
    end

    context 'connector not present' do
      let(:connector) {
        nil
      }

      let(:new_validation_states) {
        {
          'domain-one' => {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['error-id'],
                :messages => ['error']
              }
            ]
          }
        }
      }

      it_behaves_like 'does not update any validation result'
    end
  end

  describe '#convert_connector_filtering_to_job_filtering' do
    shared_examples_for 'job filtering' do
      it 'has the right filtering rules' do
        expect(described_class.convert_connector_filtering_to_job_filtering(connector_filtering)).to eq(job_filtering)
      end
    end

    context 'missing input filtering' do
      let(:connector_filtering) { nil }
      let(:job_filtering) { [] }
      it_behaves_like 'job filtering'
    end

    context 'with active rules' do
      let(:single_filtering) do
        {
          'domain' => 'default',
          'active' => {
            'rules' => ['active'],
            'advanced_snippet' => { 'active' => 'true' },
            'validation' => {}
          },
          'draft' => {
            'rules' => ['draft'],
            'advanced_snippet' => { 'draft' => 'true' },
            'validation' => {}
          }
        }
      end
      let(:connector_filtering) { single_filtering }
      let(:single_job) do
        {
          'domain' => 'default',
          'rules' => ['active'],
          'advanced_snippet' => { 'active' => 'true' },
          'warnings' => []
        }
      end
      let(:job_filtering) { [single_job] }
      it_behaves_like 'job filtering'

      context 'with multiples' do
        let(:connector_filtering) do
          [
            single_filtering,
            single_filtering.merge!('domain' => 'second')
          ]
        end
        let(:job_filtering) do
          [
            single_job,
            single_job.merge!('domain' => 'second')
          ]
        end
        it_behaves_like 'job filtering'
      end
    end
  end

  describe '#update_connector_status' do
    let(:expected_payload) do
      {
        :index => connectors_index,
        :id => connector_id,
        :body => {
          :doc => { :status => status }
        },
        :refresh => true,
        :retry_on_conflict => 3
      }
    end
    context 'with no errors' do
      let(:status) { Connectors::ConnectorStatus::CONFIGURED }

      it 'sends update request with expected body' do
        expect(es_client).to receive(:update).with(expected_payload.deep_merge(:body => { :doc => { :error => nil } }))

        described_class.update_connector_status(connector_id, status)
      end
    end

    context 'with an error status but no message' do
      let(:status) { Connectors::ConnectorStatus::ERROR }

      it 'raises an argument error' do
        expect { described_class.update_connector_status(connector_id, status) }
          .to raise_error(ArgumentError, /error_message is required/)
      end
    end

    context 'with an error status and message' do
      let(:status) { Connectors::ConnectorStatus::ERROR }
      let(:message) { 'whoops' }

      it 'sends update request with expected body' do
        expect(es_client).to receive(:update).with(expected_payload.deep_merge(:body => { :doc => { :error => message } }))

        described_class.update_connector_status(connector_id, status, message)
      end
    end
  end

  describe '#fetch_document_ids' do
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

  describe '#ensure_index_exists' do
    let(:data_index_name) { 'was-i-created-or-not' }
    let(:index_mappings) { {} }
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

  describe '#ensure_content_index_exists' do
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

  describe '#update_connector_fields' do
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
        expect(es_client).to receive(:update).with(
          :index => connectors_index,
          :id => connector_id,
          :body => { :doc => doc },
          :refresh => true,
          :retry_on_conflict => 3
        )

        described_class.update_connector_fields(connector_id, doc)
      end
    end

    context 'on version conflict' do
      let(:doc) { { :something => :something } }
      let(:seq_no) { 1 }
      let(:primary_term) { 1 }
      before(:each) do
        expect(es_client)
          .to receive(:update)
          .with(anything)
          .and_raise(
            Elastic::Transport::Transport::Errors::Conflict.new
          )
      end
      it 'raises a version changed error' do
        expect { described_class.update_connector_fields(connector_id, doc, seq_no, primary_term) }
          .to raise_error(Core::ConnectorVersionChangedError)
      end
    end
  end

  describe '.get_latest_index_in_alias' do
    let(:alias_name) { '.ent-search-connectors' }
    let(:indices) { 11.times.collect { |i| ".ent-search-connectors-v#{i}" }.to_a }

    it 'finds the latest numeric version' do
      expect(described_class.send(:get_latest_index_in_alias, alias_name, indices)).to eq('.ent-search-connectors-v10')
    end
  end

  describe '#update_connector_custom_scheduling_last_synced' do
    let(:timestamp) { Time.now.beginning_of_day }
    let(:doc) do
      {
        :custom_scheduling => { :custom_scheduling => { 'foo' => { :last_synced => nil } } },
        :_seq_no => 1,
        :_primary_term => ''
      }
    end
    let(:expected_update_args) do
      {
        :index => connectors_index,
        :id => connector_id,
        :body => { :doc => { :custom_scheduling => { 'foo' => { :last_synced => timestamp } } } },
        :refresh => true,
        :retry_on_conflict => 3
      }
    end

    before do
      allow(es_client).to receive(:get).and_return(doc)
      allow(Time).to receive(:now).and_return(timestamp)
    end

    it 'updates the custom_scheduling last_synced value' do
      described_class.update_connector_custom_scheduling_last_synced(connector_id, 'foo')

      expect(es_client).to have_received(:update).with(expected_update_args)
    end
  end
end
