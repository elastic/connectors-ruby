#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
# analyzer = Swiftype::TextAnalysis.new(:ru).to_hash

module Utility
  module Elasticsearch
    module Index
      class TextAnalysisSettings
        UNIVERSAL = 'Universal'

        LANGUAGE_DATA = {
          da: {
            name: 'Danish',
            stemmer: 'danish',
            stop_words: '_danish_'
          },
          de: {
            name: 'German',
            stemmer: 'light_german',
            stop_words: '_german_'
          },
          en: {
            name: 'English',
            stemmer: 'light_english',
            stop_words: '_english_'
          },
          es: {
            name: 'Spanish',
            stemmer: 'light_spanish',
            stop_words: '_spanish_'
          },
          fr: {
            name: 'French',
            stemmer: 'light_french',
            stop_words: '_french_',
            custom_filter_definitions: {
              'fr-elision' => {
                'type' => 'elision',
                'articles' => %w[l m t qu n s j d c jusqu quoiqu lorsqu puisqu],
                'articles_case' => true
              }
            },
            prepended_filters: [
              'fr-elision'
            ]
          },
          it: {
            name: 'Italian',
            stemmer: 'light_italian',
            stop_words: '_italian_',
            custom_filter_definitions: {
              'it-elision' => {
                'type' => 'elision',
                'articles' => %w[c l all dall dell nell sull coll pell gl agl dagl degl negl sugl un m t s v d],
                'articles_case' => true
              }
            },
            prepended_filters: [
              'it-elision'
            ]
          },
          ja: {
            name: 'Japanese',
            stemmer: 'light_english',
            stop_words: '_english_',
            postpended_filters: [
              'cjk_bigram'
            ]
          },
          ko: {
            name: 'Korean',
            stemmer: 'light_english',
            stop_words: '_english_',
            postpended_filters: [
              'cjk_bigram'
            ]
          },
          nl: {
            name: 'Dutch',
            stemmer: 'dutch',
            stop_words: '_dutch_'
          },
          pt: {
            name: 'Portuguese',
            stemmer: 'light_portuguese',
            stop_words: '_portuguese_'
          },
          'pt-br': {
            name: 'Portuguese (Brazil)',
            stemmer: 'brazilian',
            stop_words: '_brazilian_'
          },
          ru: {
            name: 'Russian',
            stemmer: 'russian',
            stop_words: '_russian_'
          },
          th: {
            name: 'Thai',
            stemmer: 'light_english',
            stop_words: '_thai_'
          },
          zh: {
            name: 'Chinese',
            stemmer: 'light_english',
            stop_words: '_english_',
            postpended_filters: [
              'cjk_bigram'
            ]
          }
        }.freeze

        DEFAULT_LANGUAGE = :en

        SUPPORTED_LANGUAGE_CODES = LANGUAGE_DATA.keys.map(&:to_s)
        FRONT_NGRAM_MAX_GRAM = 12

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
          @language_code = language_code
          @analysis_icu = analysis_icu
          @analysis_settings = icu_settings(analysis_icu)
        end

        def to_hash
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

        def language_name
          LANGUAGE_DATA[language_code][:name]
        end

        def stemmer_name
          LANGUAGE_DATA[language_code][:stemmer]
        end

        def stop_words_name_or_list
          LANGUAGE_DATA[language_code][:stop_words]
        end

        def custom_filter_definitions
          LANGUAGE_DATA[language_code][:custom_filter_definitions] || {}
        end

        def prepended_filters
          LANGUAGE_DATA[language_code][:prepended_filters] || []
        end

        def postpended_filters
          LANGUAGE_DATA[language_code][:postpended_filters] || []
        end

        def stem_filter_name
          "#{language_code}-stem-filter"
        end

        def stop_words_filter_name
          "#{language_code}-stop-words-filter"
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

          definitions['i_prefix'] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              'front_ngram'
            ]
          }

          definitions['q_prefix'] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters]
            ]
          }

          definitions['iq_text_base'] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              stop_words_filter_name
            ]
          }

          definitions['iq_text_stem'] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *prepended_filters,
              *analysis_settings[:folding_filters],
              stop_words_filter_name,
              stem_filter_name,
              *postpended_filters
            ]
          }

          definitions['iq_text_delimiter'] = {
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

          definitions['i_text_bigram'] = {
            tokenizer: analysis_settings[:tokenizer_name],
            filter: [
              *analysis_settings[:folding_filters],
              stem_filter_name,
              'bigram_joiner',
              'bigram_max_size'
            ]
          }

          definitions['q_text_bigram'] = {
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
      end
    end
  end
end
