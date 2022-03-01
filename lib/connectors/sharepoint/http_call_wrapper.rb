#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'stubs/content_source'
require 'connectors/base/config'
require 'connectors/sharepoint/extractor'

module Connectors
  module Sharepoint
    class HttpCallWrapper
      def initialize(params)
        features = {}
        @extractor = Connectors::Sharepoint::Extractor.new(
          content_source: ContentSource.new(access_token: params['access_token']),
          config: Connectors::Base::Config.new,
          features: features
        )
      end

      def get_document_batch
        results = []
        max = 100

        @extractor.yield_document_changes do |action, doc, subextractors|
          results << {
            :action => action,
            :document => doc,
            :download => nil
          }
          break if results.size > max
        end

        results
      end
    end
  end
end
