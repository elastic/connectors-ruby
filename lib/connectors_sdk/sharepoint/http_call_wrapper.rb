#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/config'
require 'connectors_sdk/sharepoint/extractor'
require 'bson'

module ConnectorsSdk
  module Sharepoint
    class HttpCallWrapper
      def initialize(params)
        features = {}
        @extractor = ConnectorsSdk::Sharepoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: 'sharepoint_online',
          authorization_data_proc: proc { { access_token: params['access_token'] } },
          client_proc: proc { ConnectorsSdk::Office365::CustomClient.new(:access_token => params['access_token'], :cursors => {}) },
          config: ConnectorsSdk::Office365::Config.new(:cursors => {}, :drive_ids => 'all'),
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
