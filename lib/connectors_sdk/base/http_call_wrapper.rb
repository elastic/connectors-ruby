#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'bson'

module ConnectorsSdk
  module Base
    class HttpCallWrapper
      def extractor(params)
        extractor_class.new(
          content_source_id: params[:content_source_id] || "GENERATED-#{BSON::ObjectId.new}",
          service_type: service_type,
          authorization_data_proc: proc { { access_token: params[:access_token] } },
          client_proc: proc { client(params) },
          config: config(params),
          features: params.fetch(:features, {}) || {}
        )
      end

      def document_batch(params)
        convert_third_party_errors do
          results = []

          extractor = extractor(params)

          extractor.yield_document_changes(:break_after_page => true, :modified_since => extractor.config.cursors['modified_since']) do |action, doc, download_args_and_proc|
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

          [results, extractor.config.cursors, extractor.completed]
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

      def authorization_uri(params)
        authorization.authorization_uri(params)
      end

      def access_token(params)
        authorization.access_token(params)
      end

      def refresh(params)
        authorization.refresh(params)
      end

      def download(params)
        extractor(params).download(params[:meta])
      end

      def source_status(params)
        health_check(params)
        { :status => 'OK', :statusCode => 200, :message => "Connected to #{name}" }
      rescue StandardError => e
        { :status => 'FAILURE', :statusCode => e.is_a?(custom_client_error) ? e.status_code : 500, :message => e.message }
      end

      def name
        raise 'Not implemented for this connector'
      end

      def service_type
        self.class::SERVICE_TYPE
      end

      private

      def convert_third_party_errors
        yield
      rescue custom_client_error => e
        raise e.status_code == 401 ? ConnectorsShared::InvalidTokenError : e
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
    end
  end
end
