#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core'

describe Core::ConnectorSettings do
  let(:elasticsearch_response) { {} }
  let(:connectors_meta) { {} }
  subject { described_class.send(:new, elasticsearch_response, connectors_meta) }

  before(:each) do
    allow(Core::ElasticConnectorActions).to receive(:connectors_meta).and_return(connectors_meta)
  end

  context '.fetch_by_id' do
    let(:connector_id) { '123' }
    let(:elasticsearch_response) do
      {
        :found => found
      }
    end
    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:get_connector).and_return(elasticsearch_response)
    end

    context 'when connector does not exist' do
      let(:found) { false }

      it 'returns nil' do
        expect(described_class.fetch_by_id(connector_id)).to be_nil
      end
    end

    context 'when connector exists' do
      let(:found) { true }

      it 'returns a connector entity' do
        expect(described_class.fetch_by_id(connector_id)).to be_kind_of(described_class)
      end
    end
  end

  context 'pipeline settings' do
    it 'has defaults' do
      expect(subject.request_pipeline).to eq(Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE)
    end

    context 'global meta defaults are present' do
      let(:connectors_meta) {
        {
          :pipeline => {
            :default_name => 'foo'
          }
        }
      }

      it 'defers to globals' do
        expect(subject.request_pipeline).to eq('foo')
      end

      context 'index specific values are present' do
        let(:elasticsearch_response) {
          {
            :_source => {
              :pipeline => {
                :name => 'bar'
              }
            }
          }
        }

        it 'defers to index specific' do
          expect(subject.request_pipeline).to eq('bar')
        end
      end
    end
  end

  describe '#filtering' do
    context 'filtering is present' do
      let(:elasticsearch_response) {
        {
          :_source => {
            :filtering => [
              {
                :domain => 'DEFAULT',
                :active => {
                  :rules => [],
                  :advanced_snippet => {},
                }
              }
            ]
          }
        }
      }

      it 'extracts filtering field' do
        filter = subject.filtering

        expect(filter[:domain]).to eq('DEFAULT')
        expect(filter[:active][:rules]).to_not be_nil
        expect(filter[:active][:advanced_snippet]).to_not be_nil
      end
    end

    context 'filtering is not present' do
      it 'returns default filtering object' do
        filtering = subject.filtering

        expect(filtering).to_not be_nil
        expect(filtering).to be_empty
      end
    end
  end

  describe '#update_last_sync!' do
    let(:id) { 'id' }
    let(:job) { double }
    let(:job_status) { Connectors::SyncStatus::ERROR }
    let(:job_error) { 'something wrong' }
    let(:terminated?) { true }
    let(:indexed_document_count) { 10 }
    let(:deleted_document_count) { 5 }
    let(:expected_connector_status) { Connectors::ConnectorStatus::ERROR }

    before(:each) do
      allow(subject).to receive(:id).and_return(id)
      allow(job).to receive(:status).and_return(job_status)
      allow(job).to receive(:error).and_return(job_error)
      allow(job).to receive(:terminated?).and_return(terminated?)
      allow(job).to receive(:[]).with(:indexed_document_count).and_return(indexed_document_count)
      allow(job).to receive(:[]).with(:deleted_document_count).and_return(deleted_document_count)
    end

    it 'updates connector' do
      expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(
        id,
        hash_including(
          :last_sync_status => job_status,
          :last_synced => anything,
          :last_sync_error => job_error,
          :status => expected_connector_status,
          :error => job_error,
          :last_indexed_document_count => indexed_document_count,
          :last_deleted_document_count => deleted_document_count
        )
      )
      subject.update_last_sync!(job)
    end

    context 'when it\'s not terminated' do
      let(:terminated?) { false }

      it 'does not update stats' do
        expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(
          id, hash_excluding(:last_indexed_document_count, :last_deleted_document_count)
        )
        subject.update_last_sync!(job)
      end
    end

    context 'with nil job' do
      let(:job) { nil }
      let(:expected_error) { 'Could\'t find the job' }

      it 'updates connector with error' do
        expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(
          id,
          hash_including(
            :last_sync_status => Connectors::SyncStatus::ERROR,
            :last_synced => anything,
            :last_sync_error => expected_error,
            :status => expected_connector_status,
            :error => expected_error
          )
        )
        subject.update_last_sync!(job)
      end
    end

    context 'with error job without error message' do
      let(:job_error) { nil }
      let(:expected_error) { 'unknown error' }

      it 'updates with error' do
        expect(Core::ElasticConnectorActions).to receive(:update_connector_fields).with(
          id, hash_including(:last_sync_error => expected_error, :error => expected_error)
        )
        subject.update_last_sync!(job)
      end
    end
  end

  describe '.fetch_native_connectors' do
    let(:connectors_meta) {
      {
        :pipeline => {
          :default_name => 'foo',
          :default_extract_binary_content => false,
          :default_reduce_whitespace => false,
          :default_run_ml_inference => true
        }
      }
    }

    let(:connectors) do
      [
         { '_id' => '123', '_source' => { 'something' => 'something', 'is_native' => true } }.with_indifferent_access,
         { '_id' => '456', '_source' => { 'something' => 'something', 'is_native' => true } }.with_indifferent_access,
         { '_id' => '789', '_source' => { 'something' => 'something', 'is_native' => true } }.with_indifferent_access
      ]
    end

    context 'when no paging is needed' do
      before(:each) do
        allow(Core::ElasticConnectorActions).to receive(:search_connectors).and_return({
          'hits' => {
            'hits' => connectors,
            'total' => {
              'value' => connectors.size
            }
          }
        })
      end

      it 'returns three connector settings instances' do
        results = described_class.fetch_native_connectors(connectors.size)

        expected_connector_ids = results.map(&:id)
        actual_connector_ids = connectors.map { |c| c['_id'] }

        expect(expected_connector_ids).to eq(actual_connector_ids)
      end
    end

    context 'when paging is needed' do
      before(:each) do
        (0..2).each do |i|
          allow(Core::ElasticConnectorActions).to receive(:search_connectors).with(anything, anything, i).and_return({
            'hits' => {
              'hits' => [connectors[i]],
              'total' => {
                'value' => connectors.size
              }
            }
          })
        end
      end

      it 'returns three connector settings instances' do
        results = described_class.fetch_native_connectors(1)

        expected_connector_ids = results.map(&:id)
        actual_connector_ids = connectors.map { |c| c['_id'] }

        expect(expected_connector_ids).to eq(actual_connector_ids)
      end

      it 'fetches connectors meta only once' do
        expect(Core::ElasticConnectorActions).to receive(:connectors_meta).exactly(1).time

        described_class.fetch_native_connectors(1)
      end
    end
  end

  shared_context 'filtering features' do
    shared_examples_for 'filtering rule feature is disabled' do
      it '' do
        expect(subject.filtering_rule_feature_enabled?).to be_falsey
      end
    end

    shared_examples_for 'filtering advanced config feature is disabled' do
      it '' do
        expect(subject.filtering_advanced_config_feature_enabled?).to be_falsey
      end
    end

    shared_examples_for 'all filtering features are disabled' do
      it '' do
        expect(subject.any_filtering_feature_enabled?).to be_falsey
      end
    end

    shared_examples_for 'at least one filtering feature is enabled' do
      it '' do
        expect(subject.any_filtering_feature_enabled?).to be_truthy
      end
    end

    let(:filtering_rules_feature_enabled) {
      true
    }

    let(:filtering_advanced_config_feature_enabled) {
      true
    }

    let(:features) {
      {
        :filtering_rules => filtering_rules_feature_enabled,
        :filtering_advanced_config => filtering_advanced_config_feature_enabled
      }
    }

    let(:elasticsearch_response) {
      {
        :_source => {
          :features => features
        }
      }
    }
  end

  describe '#features' do
    include_context 'filtering features' do
      context 'when features are not present' do
        context 'when features is an empty dict' do
          let(:features) {
            {}
          }

          it 'returns empty features' do
            expect(subject.features).to be_empty
          end
        end

        context 'when features is an empty array' do
          let(:features) {
            []
          }

          it 'returns empty features' do
            expect(subject.features).to be_empty
          end
        end

        context 'when features are nil' do
          let(:features) {
            nil
          }

          it 'returns nil features' do
            expect(subject.features).to be_nil
          end
        end
      end
    end
  end

  describe '#filtering_rule_feature_enabled?' do
    include_context 'filtering features'

    context 'when features are not present' do
      context 'when features are empty' do
        let(:features) {
          {}
        }

        it_behaves_like 'filtering rule feature is disabled'
      end

      context 'when features is an empty array' do
        let(:features) {
          []
        }

        it_behaves_like 'filtering rule feature is disabled'
      end

      context 'when features are nil' do
        let(:features) {
          nil
        }

        it_behaves_like 'filtering rule feature is disabled'
      end
    end

    context 'when features are present' do
      context 'when filtering rule feature is disabled' do
        let(:filtering_rules_feature_enabled) {
          false
        }

        it_behaves_like 'filtering rule feature is disabled'
      end

      context 'when filtering rule feature is enabled' do
        let(:filtering_rules_feature_enabled) {
          true
        }

        it 'returns enabled' do
          expect(subject.filtering_rule_feature_enabled?).to be_truthy
        end
      end
    end
  end

  describe '#filtering_advanced_config_feature_enabled?' do
    include_context 'filtering features'

    context 'when features are not present' do
      context 'when features are empty' do
        let(:features) {
          {}
        }

        it_behaves_like 'filtering advanced config feature is disabled'
      end

      context 'when features is an empty array' do
        let(:features) {
          []
        }

        it_behaves_like 'filtering advanced config feature is disabled'
      end

      context 'when features are nil' do
        let(:features) {
          nil
        }

        it_behaves_like 'filtering advanced config feature is disabled'
      end
    end

    context 'when features are present' do
      context 'when filtering advanced config feature is disabled' do
        let(:filtering_advanced_config_feature_enabled) {
          false
        }

        it_behaves_like 'filtering advanced config feature is disabled'
      end

      context 'when filtering advanced config feature is enabled' do
        let(:filtering_advanced_config_feature_enabled) {
          true
        }

        it 'returns enabled' do
          expect(subject.filtering_advanced_config_feature_enabled?).to be_truthy
        end
      end
    end
  end

  describe '#any_filtering_feature_enabled?' do
    include_context 'filtering features'

    context 'when features are not present' do
      context 'when features are empty' do
        let(:features) {
          {}
        }

        it_behaves_like 'all filtering features are disabled'
      end

      context 'when features is an empty array' do
        let(:features) {
          []
        }

        it_behaves_like 'all filtering features are disabled'
      end

      context 'when features are nil' do
        let(:features) {
          nil
        }

        it_behaves_like 'all filtering features are disabled'
      end
    end

    context 'when filtering advanced config feature and filtering rule feature are disabled' do
      let(:filtering_advanced_config_feature_enabled) {
        false
      }

      let(:filtering_rules_feature_enabled) {
        false
      }

      it_behaves_like 'all filtering features are disabled'
    end

    context 'when filtering advanced config feature is enabled and filtering rule feature is disabled' do
      let(:filtering_advanced_config_feature_enabled) {
        true
      }

      let(:filtering_rules_feature_enabled) {
        false
      }

      it_behaves_like 'at least one filtering feature is enabled'
    end

    context 'when filtering advanced config feature is disabled and filtering rule feature is enabled' do
      let(:filtering_advanced_config_feature_enabled) {
        false
      }

      let(:filtering_rules_feature_enabled) {
        true
      }

      it_behaves_like 'at least one filtering feature is enabled'
    end

    context 'when filtering advanced config feature and filtering rule feature are enabled' do
      let(:filtering_advanced_config_feature_enabled) {
        true
      }

      let(:filtering_rules_feature_enabled) {
        true
      }

      it_behaves_like 'at least one filtering feature is enabled'
    end
  end
end
