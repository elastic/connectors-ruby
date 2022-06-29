#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'byebug'

module Utility
  module Elasticsearch
    module Index
      def self.create_index_with_default_analysis_mappings(index:, language_code:, analysis_icu: false)
        settings = TextAnalysisSettings.new(
          language_code: language_code,
          analysis_icu: analysis_icu
        ).to_hash

        mappings = Mappings.default_text_fields_mappings

        create_index(
          index: index,
          body: { settings: settings, mappings: mappings }
        )
      end

      def self.create_index(arguments = {})
        es_client.indices.create(arguments)
      end

      def self.update_index_mappings(index:, mappings:)
        es_client.indices.put_mapping(index: index, body: mappings)
      end

      def self.es_client
        @es_client ||= ElasticsearchClient.client
      end
    end
  end
end
