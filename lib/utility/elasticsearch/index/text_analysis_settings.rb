#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'yaml'

module Utility
  module Elasticsearch
    module Index
      class TextAnalysisSettings
        class UnsupportedLanguageCode < StandardError; end

        DEFAULT_LANGUAGE = :en
        FRONT_NGRAM_MAX_GRAM = 12
        LANGUAGE_DATA_FILE_PATH = File.join(File.dirname(__FILE__), 'language_data.yml')

        GENERIC_FILTERS = {
          front_ngram: {
            type: 'edge_ngram',
            min_gram: 1,
            max_gram: FRONT_NGRAM_MAX_GRAM
          },
          delimiter: {
            type: 'word_delimiter_graph',
            generate_word_parts: true,
            generate_number_parts: true,
            catenate_words: true,
            catenate_numbers: true,
            catenate_all: true,
            preserve_original: false,
            split_on_case_change: true,
            split_on_numerics: true,
            stem_english_possessive: true
          },
          bigram_joiner: {
            type: 'shingle',
            token_separator: '',
            max_shingle_size: 2,
            output_unigrams: false
          },
          bigram_joiner_unigrams: {
            type: 'shingle',
            token_separator: '',
            max_shingle_size: 2,
            output_unigrams: true
          },
          bigram_max_size: {
            type: 'length',
            min: 0,
            max: 16
          }
        }.freeze

        NON_ICU_ANALYSIS_SETTINGS = {
          tokenizer_name: 'standard', folding_filters: %w(cjk_width lowercase asciifolding)
        }.freeze

        ICU_ANALYSIS_SETTINGS = {
          tokenizer_name: 'icu_tokenizer', folding_filters: %w(icu_folding)
        }.freeze

        def initialize(language_code: DEFAULT_LANGUAGE, analysis_icu: false)
          @language_code = language_code.to_sym

          raise UnsupportedLanguageCode unless language_data[@language_code]

          @analysis_icu = analysis_icu
          @analysis_settings = icu_settings(analysis_icu)
        end

        def to_h
          {
            analysis: {
              analyzer: analyzer_definitions,
              filter: filter_definitions
            },
            index: {
              similarity: {
                default: {
                  type: 'BM25'
                }
              }
            }
          }
        end

        private

        attr_reader :language_code, :analysis_settings

        def icu_settings(analysis_settings)
          return ICU_ANALYSIS_SETTINGS if analysis_settings

          NON_ICU_ANALYSIS_SETTINGS
        end

        def stemmer_name
          language_data[language_code][:stemmer]
        end

        def stop_words_name_or_list
          language_data[language_code][:stop_words]
        end

        def custom_filter_definitions
          language_data[language_code][:custom_filter_definitions] || {}
        end

        def prepended_filters
          language_data[language_code][:prepended_filters] || []
        end

        def postpended_filters
          language_data[language_code][:postpended_filters] || []
        end

        def stem_filter_name
          "#{language_code}-stem-filter".to_sym
        end

        def stop_words_filter_name
          "#{language_code}-stop-words-filter".to_sym
        end

        def filter_definitions
          definitions = GENERIC_FILTERS.dup

          definitions[stem_filter_name] = {
            type: 'stemmer',
            name: stemmer_name
          }

          definitions[stop_words_filter_name] = {
            type: 'stop',
            stopwords: stop_words_name_or_list
          }

          definitions.merge(custom_filter_definitions)
        end

        def analyzer_definitions
          definitions = {}

          definitions[:i_prefix] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              'front_ngram'
            ]
          }

          definitions[:q_prefix] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters]
            ]
          }

          definitions[:iq_text_base] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              stop_words_filter_name
            ]
          }

          definitions[:iq_text_stem] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *prepended_filters,
              *analysis_settings[:folding_filters],
              stop_words_filter_name,
              stem_filter_name,
              *postpended_filters
            ]
          }

          definitions[:iq_text_delimiter] = {
            tokenizer: 'whitespace',
            filter: [
              *prepended_filters,
              'delimiter',
              *analysis_settings[:folding_filters],
              stop_words_filter_name,
              stem_filter_name,
              *postpended_filters
            ]
          }

          definitions[:i_text_bigram] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              stem_filter_name,
              'bigram_joiner',
              'bigram_max_size'
            ]
          }

          definitions[:q_text_bigram] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              stem_filter_name,
              'bigram_joiner_unigrams',
              'bigram_max_size'
            ]
          }

          definitions
        end

        def language_data
          @language_data ||= YAML.safe_load(
            File.read(LANGUAGE_DATA_FILE_PATH),
            symbolize_names: true
          )
        end
      end
    end
  end
end
