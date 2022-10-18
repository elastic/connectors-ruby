#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Utility
  module Elasticsearch
    module Index
      module Mappings
        ENUM_IGNORE_ABOVE = 2048

        DATE_FIELD_MAPPING = {
          type: 'date'
        }

        KEYWORD_FIELD_MAPPING = {
          type: 'keyword'
        }

        TEXT_FIELD_MAPPING = {
          type: 'text',
          analyzer: 'iq_text_base',
          index_options: 'positions',
          fields: {
            'stem': {
              type: 'text',
              analyzer: 'iq_text_stem'
            },
            'prefix' => {
              type: 'text',
              analyzer: 'i_prefix',
              search_analyzer: 'q_prefix',
            },
            'delimiter' => {
              type: 'text',
              analyzer: 'iq_text_delimiter',
            },
            'joined': {
              type: 'text',
              analyzer: 'i_text_bigram',
              search_analyzer: 'q_text_bigram',
            },
            'enum': {
              type: 'keyword',
              ignore_above: ENUM_IGNORE_ABOVE
            }
          }
        }

        WORKPLACE_SEARCH_SUBEXTRACTION_STAMP_FIELD_MAPPINGS = {
          _subextracted_as_of: DATE_FIELD_MAPPING,
          _subextracted_version: KEYWORD_FIELD_MAPPING
        }.freeze

        CRAWLER_FIELD_MAPPINGS = {
          additional_urls: KEYWORD_FIELD_MAPPING,
          body_content: TEXT_FIELD_MAPPING,
          domains: KEYWORD_FIELD_MAPPING,
          headings: TEXT_FIELD_MAPPING,
          last_crawled_at: DATE_FIELD_MAPPING,
          links: KEYWORD_FIELD_MAPPING,
          meta_description: TEXT_FIELD_MAPPING,
          meta_keywords: KEYWORD_FIELD_MAPPING,
          title: TEXT_FIELD_MAPPING,
          url: KEYWORD_FIELD_MAPPING,
          url_host: KEYWORD_FIELD_MAPPING,
          url_path: KEYWORD_FIELD_MAPPING,
          url_path_dir1: KEYWORD_FIELD_MAPPING,
          url_path_dir2: KEYWORD_FIELD_MAPPING,
          url_path_dir3: KEYWORD_FIELD_MAPPING,
          url_port: KEYWORD_FIELD_MAPPING,
          url_scheme: KEYWORD_FIELD_MAPPING
        }.freeze

        def self.default_text_fields_mappings(connectors_index:, crawler_index: false)
          {
            dynamic: true,
            dynamic_templates: [
              {
                data: {
                  match_mapping_type: 'string',
                  mapping: TEXT_FIELD_MAPPING
                }
              }
            ],
            properties: {
              id: KEYWORD_FIELD_MAPPING
            }.tap do |properties|
              properties.merge!(WORKPLACE_SEARCH_SUBEXTRACTION_STAMP_FIELD_MAPPINGS) if connectors_index
            end.tap do |properties|
              properties.merge!(CRAWLER_FIELD_MAPPINGS) if crawler_index
            end
          }
        end
      end
    end
  end
end
