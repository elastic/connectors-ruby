#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/config'
require 'connectors_sdk/share_point/extractor'
require 'connectors_sdk/share_point/authorization'
require 'connectors_sdk/base/http_call_wrapper'

module ConnectorsSdk
  module SharePoint
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'share_point'

      def name
        'SharePoint'
      end

      def extractor(params)
        cursors = params.fetch(:cursors, {}) || {}
        features = params.fetch(:features, {}) || {}

        # XXX can we cache that class across calls?
        ConnectorsSdk::SharePoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: SERVICE_TYPE,
          authorization_data_proc: proc { { access_token: params[:access_token] } },
          client_proc: proc { ConnectorsSdk::Office365::CustomClient.new(:access_token => params[:access_token], :cursors => cursors) },
          config: ConnectorsSdk::Office365::Config.new(:cursors => cursors, :drive_ids => 'all', :index_permissions => params[:index_permissions] || false),
          features: features
        )
      end

      def extract(params)
        extractor = extractor(params)

        extractor.yield_document_changes(:modified_since => extractor.config.cursors[:modified_since]) do |action, doc, download_args_and_proc|
          download_obj = nil
          if download_args_and_proc
            download_obj = {
              id: download_args_and_proc[0],
              name: download_args_and_proc[1],
              size: download_args_and_proc[2],
              download_args: download_args_and_proc[3]
            }
          end

          doc = {
            :action => action,
            :document => doc,
            :download => download_obj
          }

          yield doc
        end
      rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::InvalidTokenError : e
      end

      def service_type
        SERVICE_TYPE
      end

      private

      def extractor_class
        ConnectorsSdk::SharePoint::Extractor
      end

      def authorization
        ConnectorsSdk::SharePoint::Authorization
      end

      def client(params)
        ConnectorsSdk::Office365::CustomClient.new(:access_token => params[:access_token], :cursors => params.fetch(:cursors, {}) || {})
      end

      def custom_client_error
        ConnectorsSdk::Office365::CustomClient::ClientError
      end

      def config(params)
        ConnectorsSdk::Office365::Config.new(
          :cursors => params.fetch(:cursors, {}) || {},
          :drive_ids => 'all',
          :index_permissions => params[:index_permissions] || false
        )
      end

      def health_check(params)
        client(params).me
      end
    end
  end
end
