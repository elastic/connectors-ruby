#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/config'
require 'connectors_sdk/share_point/extractor'
require 'bson'

module ConnectorsSdk
  module SharePoint
    class HttpCallWrapper
      def initialize(params)
        cursors = params['cursors'] || {}
        features = params['features'] || {},

        @extractor = ConnectorsSdk::SharePoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: 'sharepoint_online',
          authorization_data_proc: proc { { access_token: params['access_token'] } },
          client_proc: proc { ConnectorsSdk::Office365::CustomClient.new(:access_token => params['access_token'], :cursors => cursors) },
          config: ConnectorsSdk::Office365::Config.new(:cursors => cursors, :drive_ids => 'all'),
          features: features
        )
      end

      def document_batch
        results = []

        @extractor.yield_document_changes(:break_after_page => true) do |action, doc, _subextractors|
          results << {
            :action => action,
            :document => doc,
            :download => nil
          }
        end

        results
      end

      def cursors
        @extractor.config.cursors
      end

      def cursors_modified_since_start?
        @extractor.cursors_modified_since_start?

      def deleted(ids)
        results = []
        @extractor.yield_deleted_ids(ids) do |id|
          results << id
        end
        results
      end

      def permissions(user_id)
        @extractor.yield_permissions(user_id) do |permissions|
          return permissions
        end
      end
    end
  end
end
