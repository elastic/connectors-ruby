#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_shared'
require 'signet'
require 'signet/oauth_2'
require 'signet/oauth_2/client'

module ConnectorsSdk
  module Base
    class Authorization
      class << self
        def authorization_uri(params)
          missing = missing_fields(params, %w[client_id])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:response_type] = 'code'
          params[:additional_parameters] = additional_parameters
          client = oauth_client(params)
          client.authorization_uri.to_s
        end

        def access_token(params)
          missing = missing_fields(params, %w[client_id client_secret code redirect_uri])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:grant_type] = 'authorization_code'
          client = oauth_client(params)
          client.fetch_access_token
        end

        def refresh(params)
          missing = missing_fields(params, %w[client_id client_secret refresh_token])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:grant_type] = 'refresh_token'
          client = oauth_client(params)
          client.refresh!
        rescue StandardError => e
          ConnectorsShared::ExceptionTracking.log_exception(e)
          raise ConnectorsShared::TokenRefreshFailedError
        end

        def oauth_client(params)
          options = params.merge(
            :authorization_uri => authorization_url,
            :token_credential_uri => token_credential_uri,
            :scope => oauth_scope
          )
          options[:state] = JSON.dump(options[:state]) if options[:state]
          Signet::OAuth2::Client.new(options)
        end

        def missing_fields(params, required = [])
          Array.wrap(required).select { |field| params[field.to_sym].nil? }
        end

        def oauth_scope
          raise 'Not implemented for this connector'
        end

        private

        def authorization_url
          raise 'Not implemented for this connector'
        end

        def token_credential_uri
          raise 'Not implemented for this connector'
        end

        def additional_parameters
          raise 'Not implemented for this connector'
        end
      end
    end
  end
end
