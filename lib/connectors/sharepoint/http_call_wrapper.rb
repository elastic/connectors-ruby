#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'stubs/content_source'
require 'connectors/office365/config'
require 'connectors/sharepoint/extractor'
require 'bson'

module Connectors
  module Sharepoint
    class HttpCallWrapper
      def initialize(params)
        features = {}
        @extractor = Connectors::Sharepoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: 'sharepoint_online',
          authorization_data_proc: proc { { access_token: params['access_token']} },
          client_proc: proc { Connectors::Office365::CustomClient.new(:access_token => params['access_token'], :cursors => {}) },
          config: Connectors::Office365::Config.new(:cursors => {}, :drive_ids => 'all'),
          features: features
        )
      end

      def document_batch
        results = []
        max = 100

        @extractor.yield_document_changes do |action, doc, _subextractors|
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
