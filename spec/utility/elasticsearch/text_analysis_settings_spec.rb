# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'spec_helper'
require 'utility/elasticsearch/index/text_analysis_settings'

describe Utility::Elasticsearch::Index::TextAnalysisSettings do
  describe '#initialize' do
    it 'creates an TextAnalysisSettings object' do
      expect(described_class.new).to be_kind_of(Utility::Elasticsearch::Index::TextAnalysisSettings)
    end

    it 'accept symbols as language_code' do
      expect { described_class.new(language_code: :de) }.not_to raise_error(
        Utility::Elasticsearch::Index::TextAnalysisSettings::UnsupportedLanguageCode
      )
    end

    it 'accept strings as language_code' do
      expect { described_class.new(language_code: 'de') }.not_to raise_error(
        Utility::Elasticsearch::Index::TextAnalysisSettings::UnsupportedLanguageCode
      )
    end
  end

  describe '#to_h' do
    let(:language_code) { Utility::Elasticsearch::Index::TextAnalysisSettings::DEFAULT_LANGUAGE }
    let(:subject) { described_class.new(language_code: language_code, analysis_icu: analysis_icu).to_h }
    let(:expected_analyzer_keys) { %i(i_prefix q_prefix iq_text_base iq_text_stem iq_text_delimiter i_text_bigram q_text_bigram) }
    let(:non_icu_filters) { Utility::Elasticsearch::Index::TextAnalysisSettings::NON_ICU_ANALYSIS_SETTINGS[:folding_filters] }
    let(:icu_filters) { Utility::Elasticsearch::Index::TextAnalysisSettings::ICU_ANALYSIS_SETTINGS[:folding_filters] }
    let(:filters) { subject[:analysis][:analyzer].values.flat_map { |v| v[:filter] }.uniq }

    context 'when analysis_icu is false' do
      let(:analysis_icu) { false }

      it { is_expected.to be_kind_of(Hash) }
      it { is_expected.to include(analysis: include(:analyzer => hash_including(*expected_analyzer_keys))) }

      it 'has non icu folding filters' do
        expect(filters).to include(*non_icu_filters)
      end

      it 'does not have icu folding filters' do
        expect(filters).not_to include(*icu_filters)
      end
    end

    context 'when analysis_icu is true' do
      let(:analysis_icu) { true }

      it { is_expected.to be_kind_of(Hash) }
      it { is_expected.to include(analysis: include(analyzer: hash_including(*expected_analyzer_keys))) }

      it 'does not have non icu folding filters' do
        expect(filters).not_to include(*non_icu_filters)
      end

      it 'has icu folding filters' do
        expect(filters).to include(*icu_filters)
      end
    end

    context 'when the language_code is not supported' do
      let(:language_code) { :unsupported_language_code }
      let(:analysis_icu) { false }

      it 'raises an error' do
        expect { described_class.new(language_code: language_code, analysis_icu: analysis_icu) }.to raise_error(
          Utility::Elasticsearch::Index::TextAnalysisSettings::UnsupportedLanguageCode
        )
      end
    end

    context 'when the language_code is supported' do
      let(:language_code) { :fr }
      let(:analysis_icu) { false }
      let(:subject) { described_class.new(language_code: language_code, analysis_icu: analysis_icu).to_h[:analysis][:filter] }

      it { is_expected.to have_key(:"#{language_code}-stem-filter") }
      it { is_expected.to have_key(:"#{language_code}-stop-words-filter") }
      it { is_expected.to have_key(:"#{language_code}-elision") }
    end
  end
end
