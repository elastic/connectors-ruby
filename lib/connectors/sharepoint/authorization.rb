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
          params[:additional_parameters] = { :prompt => 'consent' }
          client = oauth_client(params)
          client.authorization_uri.to_s
        end

        def access_token(params)
          params[:grant_type] = 'authorization_code'
          client = oauth_client(params)
          client.fetch_access_token.to_json
        end

        def oauth_client(params)
          options = params.merge(
            :authorization_uri => authorization_url,
            :token_credential_uri => token_credential_uri,
            :scope => oauth_scope
          ).with_indifferent_access
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
      end
    end
  end
end
