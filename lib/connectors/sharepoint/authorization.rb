#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

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
          client = Signet::OAuth2::Client.new(
            authorization_uri: authorization_url,
            token_credential_uri: token_credential_uri,
            scope: oauth_scope,
            client_id: params[:client_id],
            client_secret: params[:client_secret],
            redirect_uri: params[:redirect_uri],
            state: JSON.dump(params[:state]),
            additional_parameters: { prompt: 'consent' }
          )
          client.authorization_uri.to_s
        end

        def access_token(params)
          oauth_data = {
            token_credential_uri: token_credential_uri,
            client_id: params[:client_id],
            client_secret: params[:client_secret]
          }
          # on the first dance
          oauth_data[:code] = params[:code] if params[:code].present?
          oauth_data[:redirect_uri] = params[:redirect_uri] if params[:redirect_uri].present?
          oauth_data[:session_state] = params[:session_state] if params[:session_state].present?
          oauth_data[:state] = params[:state] if params[:state].present?

          # on refresh dance
          if params[:refresh_token].present?
            oauth_data[:refresh_token] = params[:refresh_token]
            oauth_data[:grant_type] = :authorization
          end
          client = Signet::OAuth2::Client.new(oauth_data)
          client.fetch_access_token.to_json
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
      end
    end
  end
end
