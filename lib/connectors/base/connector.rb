#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'

module Connectors
  module Base
    class Connector
      attr_reader :index_name

      def initialize(index_name)
        @index_name = index_name
      end

      def sync(connector); end

      def extractor(params)
        content_source_id = params.fetch(:content_source_id)
        secret_storage = params[:secret_storage]

        extractor_class.new(
          content_source_id: content_source_id || "GENERATED-#{BSON::ObjectId.new}",
          service_type: service_type,
          authorization_data_proc: proc do
            secret = secret_storage.fetch_secret(content_source_id)
            {
              access_token: secret[:access_token]
            }
          end,
          client_proc: proc {
            secret = secret_storage.fetch_secret(content_source_id)
            params[:access_token] = secret[:access_token]
            client(params)
          },
          config: config(params),
          features: params.fetch(:features, {}) || {}
        )
      end

      def extract(params)
        convert_third_party_errors do
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

          extractor.config.to_h[:cursors]
        end
      end

      def deleted(params)
        convert_third_party_errors do
          results = []
          extractor(params).yield_deleted_ids(params[:ids]) do |id|
            results << id
          end
          results
        end
      end

      def permissions(params)
        convert_third_party_errors do
          extractor(params).yield_permissions(params[:user_id]) do |permissions|
            return permissions
          end
        end
      end

      def download(params)
        extractor(params).download(params[:meta])
      end

      def authorization_uri(params)
        authorization.authorization_uri(params)
      end

      def access_token(params)
        authorization.access_token(params)
      end

      def refresh(params)
        authorization.refresh(params)
      end

      def source_status(params)
        health_check(params)
        { :status => 'OK', :statusCode => 200, :message => "Connected to #{display_name}" }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(custom_client_error) ? e.status_code : 500, :message => e.message }
      end

      def compare_secrets(*)
        raise 'Not implemented for this connector'
      end

      def display_name
        raise 'Not implemented for this connector'
      end

      def service_type
        self.class::SERVICE_TYPE
      end

      def connection_requires_redirect
        false
      end

      def configurable_fields
        []
      end

      private

      def es_client
        @es_client ||= Utility::EsClientFactory.client(index_name)
      end

      def convert_third_party_errors
        yield
      rescue custom_client_error => e
        raise e.status_code == 401 ? Utility::InvalidTokenError : e
      end

      def extractor_class
        raise 'Not implemented for this connector'
      end

      def authorization
        raise 'Not implemented for this connector'
      end

      def client(*)
        raise 'Not implemented for this connector'
      end

      def custom_client_error
        raise 'Not implemented for this connector'
      end

      def config(*)
        raise 'Not implemented for this connector'
      end

      def health_check(*)
        raise 'Not implemented for this connector'
      end

      def missing_secrets?(params)
        missing = %w[secret other_secret].select { |field| params[field.to_sym].nil? }
        unless missing.blank?
          raise Utility::ClientError.new("Missing required fields: #{missing.join(', ')}")
        end
      end
    end
  end
end
