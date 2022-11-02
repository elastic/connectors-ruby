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

  context 'pipeline settings' do
    it 'has defaults' do
      expect(subject.request_pipeline).to eq(Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE)
      expect(subject.extract_binary_content?).to eq(Core::ConnectorSettings::DEFAULT_EXTRACT_BINARY_CONTENT)
      expect(subject.reduce_whitespace?).to eq(Core::ConnectorSettings::DEFAULT_REDUCE_WHITESPACE)
      expect(subject.run_ml_inference?).to eq(Core::ConnectorSettings::DEFAULT_RUN_ML_INFERENCE)
    end

    context 'global meta defaults are present' do
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

      it 'defers to globals' do
        expect(subject.request_pipeline).to eq('foo')
        expect(subject.extract_binary_content?).to eq(false)
        expect(subject.reduce_whitespace?).to eq(false)
        expect(subject.run_ml_inference?).to eq(true)
      end

      context 'index specific values are present' do
        let(:elasticsearch_response) {
          {
            :pipeline => {
              :name => 'bar',
              :extract_binary_content => true,
              :reduce_whitespace => false,
              :run_ml_inference => true
            }
          }
        }

        it 'defers to index specific' do
          expect(subject.request_pipeline).to eq('bar')
          expect(subject.extract_binary_content?).to eq(true)
          expect(subject.reduce_whitespace?).to eq(false)
          expect(subject.run_ml_inference?).to eq(true)
        end
      end
    end
  end

  context '.filtering' do
    context 'filtering is present' do
      let(:elasticsearch_response) {
        {
          :filtering => [
            {
              :domain => 'DEFAULT',
              :active => {
                :active_rules => [],
                :advanced_config => {},
              }
            }
          ]
        }
      }

      it 'extracts filtering field' do
        filtering = subject.filtering
        first_filter = filtering[0]

        expect(first_filter[:domain]).to eq('DEFAULT')
        expect(first_filter[:active][:active_rules]).to_not be_nil
        expect(first_filter[:active][:advanced_config]).to_not be_nil
      end
    end

    context 'filtering is not present' do
      it 'returns default filtering object' do
        filtering = subject.filtering

        expect(filtering).to_not be_nil
        expect(filtering.empty?).to eq(true)
      end
    end
  end

  context '.active_advanced_filter_config' do
    shared_examples_for 'extracts active_filter_config' do
      it 'extracts active_advanced_filter_config' do
        advanced_config = subject.active_filter_config

        expect(advanced_config).to_not be_nil
        expect(advanced_config[:find][:options][:skip]).to eq(10)
      end
    end

    context 'active advanced config exists as one element array' do
      let(:elasticsearch_response) {
        {
          :filtering => [
            {
              :domain => 'DEFAULT',
              :active => {
                :active_rules => [],
                :advanced_config => {
                  :find => {
                    :options => {
                      :skip => 10
                    }
                  }
                },
              },
              :draft => {
                :active_rules => [],
                :advanced_config => {}
              }
            },
          ]
        }
      }

      it_behaves_like 'extracts active_filter_config'
    end

    context 'active advanced config exists as an object' do
      let(:elasticsearch_response) {
        {
          :filtering => {
              :domain => 'DEFAULT',
              :active => {
                :active_rules => [],
                :advanced_config => {
                  :find => {
                    :options => {
                      :skip => 10
                    }
                  }
                },
              },
              :draft => {
                :active_rules => [],
                :advanced_config => {}
              }
            }
        }
      }

      it_behaves_like 'extracts active_filter_config'
    end

    context 'no active advanced_config exists' do
      let(:elasticsearch_response) {
        {
          :filtering => [
            {
              :domain => 'DEFAULT',
              :active => {
                :active_rules => [],
                :advanced_config => {}
              },
              :draft => {
                :active_rules => [],
                :advanced_config => {
                  :find => {
                    :options => {
                      :skip => 10
                    }
                  }
                }
              }
            }
          ]
        }
      }

      it 'returns empty hash, if no active advanced_config exists' do
        advanced_config = subject.active_filter_config

        expect(advanced_config.empty?).to eq(true)
      end
    end

    context 'no filtering object exists' do
      let(:elasticsearch_response) {
        {
          # no :filtering present
        }
      }

      it 'returns empty hash, if no filtering hash exists' do
        advanced_config = subject.active_filter_config

        expect(advanced_config.empty?).to eq(true)
      end
    end
  end

  context '.fetch_native_connectors' do
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

    before(:each) do
      allow(Core::ElasticConnectorActions).to receive(:connectors_meta).and_return(connectors_meta)
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
end
