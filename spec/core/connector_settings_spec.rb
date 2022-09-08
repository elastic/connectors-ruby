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
end
