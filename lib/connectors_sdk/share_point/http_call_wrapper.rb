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
        cursors = params.fetch(:cursors, {}) || {}
        features = params.fetch(:features, {}) || {}

        # XXX can we cache that class across calls?
        ConnectorsSdk::SharePoint::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: 'sharepoint_online',
          authorization_data_proc: proc { { access_token: params[:access_token] } },
          client_proc: proc { ConnectorsSdk::Office365::CustomClient.new(:access_token => params[:access_token], :cursors => cursors) },
          config: ConnectorsSdk::Office365::Config.new(:cursors => cursors, :drive_ids => 'all'),
          features: features
        )
      end

      def document_batch(params)
        results = []

        @extractor = extractor(params)

        @extractor.yield_document_changes(:break_after_page => true, :modified_since => @extractor.config.cursors['modified_since']) do |action, doc, download_args_and_proc|
          download_obj = nil
          if download_args_and_proc
            download_obj = {
              id: download_args_and_proc[0],
              name: download_args_and_proc[1],
              size: download_args_and_proc[2],
              download_args: download_args_and_proc[3]
            }
          end

          results << {
            :action => action,
            :document => doc,
            :download => download_obj
          }
        end

        results
      rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::SecretInvalidError : e
      end

      def cursors
        @extractor.config.cursors
      end

      def deleted(params)
        results = []
        extractor(params).yield_deleted_ids(params[:ids]) do |id|
          results << id
        end
        results
      rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::SecretInvalidError : e
      end

      def permissions(params)
        extractor(params).yield_permissions(params[:user_id]) do |permissions|
          return permissions
        end
      rescue ConnectorsSdk::Office365::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::SecretInvalidError : e
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

      def download(params)
        extractor(params).download(params[:meta])
      end

      def name
        'SharePoint'
      end

      def source_status(access_token)
        client = ConnectorsSdk::Office365::CustomClient.new(:access_token => access_token)
        client.me
        { :status => 'OK', :statusCode => 200, :message => 'Connected to SharePoint' }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(ConnectorsSdk::Office365::CustomClient::ClientError) ? e.status_code : 500, :message => e.message }
      end
    end
  end
end
