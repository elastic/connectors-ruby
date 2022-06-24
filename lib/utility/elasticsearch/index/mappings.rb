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

        WORKPLACE_SEARCH_SUBEXTRACTION_STAMP_FIELD_MAPPINGS = {
          _subextracted_as_of: {
            type: 'date'
          },
          _subextracted_version: {
            type: 'keyword'
          }
        }.freeze

        def self.default_text_fields_mappings
          {
            dynamic: true,
            dynamic_templates: [
              {
                permissions: {
                  match: '_*_permissions',
                  mapping: {
                    type: 'keyword'
                  }
                }
              },
              {
                thumbnails: {
                  match: '_thumbnail_*',
                  mapping: {
                    type: 'binary'
                  }
                }
              },
              {
                data: {
                  match_mapping_type: 'string',
                  mapping: {
                    type: 'text',
                    analyzer: 'iq_text_base',
                    index_options: 'freqs',
                    fields: {
                      'stem': {
                        type: 'text',
                        analyzer: 'iq_text_stem'
                      },
                      'prefix' => {
                        type: 'text',
                        analyzer: 'i_prefix',
                        search_analyzer: 'q_prefix',
                        index_options: 'docs'
                      },
                      'delimiter' => {
                        type: 'text',
                        analyzer: 'iq_text_delimiter',
                        index_options: 'freqs'
                      },
                      'joined': {
                        type: 'text',
                        analyzer: 'i_text_bigram',
                        search_analyzer: 'q_text_bigram',
                        index_options: 'freqs'
                      },
                      'enum': {
                        type: 'keyword',
                        ignore_above: ENUM_IGNORE_ABOVE
                      }
                    }
                  }
                }
              }
            ],
            properties: {
              id: {
                type: 'keyword'
              }
            }
          }
        end
      end
    end
  end
end
