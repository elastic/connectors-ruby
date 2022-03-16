#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/config'
require 'connectors_sdk/share_point/extractor'
require 'connectors_sdk/share_point/authorization'
require 'bson'

module ConnectorsSdk
  module SharePoint
    SERVICE_TYPE = 'share_point'

    class HttpCallWrapper
      def extractor(params)
        features = {}

        # XXX can we cache that class across calls?
        ConnectorsSdk::SharePoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: 'sharepoint_online',
          authorization_data_proc: proc { { access_token: params['access_token'] } },
          client_proc: proc { ConnectorsSdk::Office365::CustomClient.new(:access_token => params['access_token'], :cursors => {}) },
          config: ConnectorsSdk::Office365::Config.new(:cursors => {}, :drive_ids => 'all'),
          features: features
        )
      end

      def document_batch(params)
        results = []
        max = 100

        extractor(params).yield_document_changes do |action, doc, _subextractors|
          results << {
            :action => action,
            :document => doc,
            :download => nil
          }
          break if results.size > max
        end

        results
      end

      def deleted(params)
        results = []
        extractor(params).yield_deleted_ids(params['ids']) do |id|
          results << id
        end
        results
      end

      def permissions(params)
        extractor(params).yield_permissions(params['user_id']) do |permissions|
          return permissions
        end
      end

      def authorization_uri(body)
        ConnectorsSdk::SharePoint::Authorization.authorization_uri(body)
      end

      def access_token(params)
        ConnectorsSdk::SharePoint::Authorization.access_token(params)
      end

      def refresh(params)
        ConnectorsSdk::SharePoint::Authorization.refresh(params)
      end
    end
  end
end
