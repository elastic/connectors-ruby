#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'app/config'

describe App do
  describe '.ent_search_es_config' do
    let(:ent_search_config_path) { 'path' }

    before(:each) do
      allow(ENV).to receive(:[]).with('ENT_SEARCH_CONFIG_PATH').and_return(ent_search_config_path)
    end

    context 'when ENT_SEARCH_CONFIG_PATH is not set' do
      let(:ent_search_config_path) { nil }
      it 'returns nil' do
        expect(described_class.ent_search_es_config).to be_nil
      end
    end

    context 'when loading of config file fails' do
      before(:each) do
        allow(YAML).to receive(:load_file).with(ent_search_config_path).and_raise(StandardError)
      end

      it 'returns nil' do
        expect(described_class.ent_search_es_config).to be_nil
      end
    end

    context 'when loading of config file succeeds' do
      let(:config_hash) do
        {
          'elasticsearch.host' => 'http://localhost:9200',
          'elasticsearch.username' => 'elastic',
          'elasticsearch.password' => 'changeme',
          'elasticsearch.headers' => {
            'x-pass-through' => true
          }
        }
      end

      let(:expected_es_config) do
        {
          :hosts => [
            {
              scheme: 'http',
              user: 'elastic',
              password: 'changeme',
              host: 'localhost',
              port: 9200
            }
          ],
          :headers => {
            'x-pass-through' => true
          }
        }
      end

      before(:each) do
        allow(YAML).to receive(:load_file).with(ent_search_config_path).and_return(config_hash)
      end

      context 'when config is an empty file' do
        let(:config_hash) { false }

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when host is missing' do
        let(:config_hash) { super().except('elasticsearch.host') }

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when username is missing' do
        let(:config_hash) { super().except('elasticsearch.username') }

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when password is missing' do
        let(:config_hash) { super().except('elasticsearch.password') }

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when host is an invalid uri' do
        let(:config_hash) do
          super().tap do |out|
            out['elasticsearch.host'] = '%^^&'
          end
        end

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when host is not a HTTP or HTTPS URI' do
        let(:config_hash) do
          super().tap do |out|
            out['elasticsearch.host'] = 'ftp://localhost:21'
          end
        end

        it 'returns nil' do
          expect(described_class.ent_search_es_config).to be_nil
        end
      end

      context 'when YAML is nested' do
        let(:config_hash) do
          {
            'elasticsearch' => {
              'host' => 'http://localhost:9200',
              'username' => 'elastic',
              'password' => 'changeme',
              'headers' => {
                'x-pass-through' => true
              }
            }
          }
        end

        it 'returns expected elasticsearch config' do
          expect(described_class.ent_search_es_config).to eq(expected_es_config)
        end
      end

      it 'returns expected elasticsearch config' do
        expect(described_class.ent_search_es_config).to eq(expected_es_config)
      end
    end
  end
end
