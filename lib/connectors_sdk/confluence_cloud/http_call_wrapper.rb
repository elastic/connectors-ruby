#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/atlassian/config'
require 'connectors_sdk/confluence_cloud/extractor'
require 'connectors_sdk/confluence_cloud/authorization'
require 'connectors_sdk/confluence_cloud/custom_client'
require 'bson'

module ConnectorsSdk
  module ConfluenceCloud
    SERVICE_TYPE = 'confluence_cloud'

    class HttpCallWrapper
      def extractor(params)
        cursors = params.fetch(:cursors, {}) || {}
        features = params.fetch(:features, {}) || {}
        cloud_id = params.fetch(:cloud_id, nil)
        base_url = params.fetch(:base_url, nil)
        if base_url.nil?
          base_url = api_base_url(cloud_id)
        end

        # XXX can we cache that class across calls?
        ConnectorsSdk::ConfluenceCloud::Extractor.new(
          content_source_id: BSON::ObjectId.new,
          service_type: SERVICE_TYPE,
          authorization_data_proc: proc {
            {
              access_token: params[:access_token],
              basic_auth_token: params[:basic_auth_token]
            }
          },
          client_proc: proc {
            ConnectorsSdk::ConfluenceCloud::CustomClient.new(
              :base_url => base_url,
              :access_token => params[:access_token],
              :basic_auth_token => params[:basic_auth_token]
            )
          },
          config: ConnectorsSdk::Atlassian::Config.new(:base_url => base_url, :cursors => cursors),
          features: features
        )
      end

      def cursors
        @extractor.config.cursors
      end

      def document_batch(params)
        results = []

        @extractor = extractor(params)

        @extractor.yield_document_changes(:modified_since => @extractor.config.cursors['modified_since']) do |action, doc, download_args_and_proc|
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
      rescue ConnectorsSdk::Atlassian::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::InvalidTokenError : e
      end

      def deleted(params)
        results = []
        extractor(params).yield_deleted_ids(params[:ids]) do |id|
          results << id
        end
        results
      rescue ConnectorsSdk::Atlassian::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::InvalidTokenError : e
      end

      def permissions(params)
        extractor(params).yield_permissions(params[:user_id]) do |permissions|
          return permissions
        end
      rescue ConnectorsSdk::Atlassian::CustomClient::ClientError => e
        raise e.status_code == 401 ? ConnectorsShared::InvalidTokenError : e
      end

      def authorization_uri(body)
        ConnectorsSdk::ConfluenceCloud::Authorization.authorization_uri(body)
      end

      def access_token(params)
        ConnectorsSdk::ConfluenceCloud::Authorization.access_token(params)
      end

      def refresh(params)
        ConnectorsSdk::ConfluenceCloud::Authorization.refresh(params)
      end

      def download(params)
        extractor(params).download(params[:meta])
      end

      def name
        'Confluence Cloud'
      end

      def source_status(params)
        cloud_id = params.fetch(:cloud_id, nil)
        base_url = params.fetch(:base_url, nil)
        client = ConnectorsSdk::ConfluenceCloud::CustomClient.new(
          :base_url => base_url.nil? ? api_base_url(cloud_id) : base_url,
          :access_token => params[:access_token],
          :basic_auth_token => params[:basic_auth_token]
        )
        client.me
        { :status => 'OK', :statusCode => 200, :message => 'Connected to Confluence Cloud' }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(ConnectorsSdk::Atlassian::CustomClient::ClientError) ? e.status_code : 500, :message => e.message }
      end

      private

      def api_base_url(cloud_id)
        "https://api.atlassian.com/ex/confluence/#{cloud_id}"
      end
    end
  end
end
