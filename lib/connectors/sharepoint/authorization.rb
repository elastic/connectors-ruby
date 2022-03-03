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

module Connectors
  module Sharepoint
    class Authorization
      class << self
        def authorization_url
          'https://login.microsoftonline.com/common/oauth2/v2.0/authorize'
        end

        def token_credential_uri
          'https://login.microsoftonline.com/common/oauth2/v2.0/token'
        end

        def authorization_uri(params)
          missing = missing_fields(params, %w[client_id])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:response_type] = 'code'
          params[:additional_parameters] = { :prompt => 'consent' }
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
          client.fetch_access_token.to_json
        end

        def refresh(params)
          missing = missing_fields(params, %w[client_id client_secret refresh_token redirect_uri])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:grant_type] = 'refresh_token'
          client = oauth_client(params)
          client.refresh!.to_json
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

        def oauth_scope
          %w[
            User.ReadBasic.All
            Group.Read.All
            Directory.AccessAsUser.All
            Files.Read
            Files.Read.All
            Sites.Read.All
            offline_access
          ]
        end

        def missing_fields(params, required = [])
          Array.wrap(required).select { |field| params[field.to_sym].nil? }
        end
      end
    end
  end
end
