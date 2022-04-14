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
  module ConfluenceCloud
    class Authorization
      class << self
        def authorization_url
          'https://auth.atlassian.com/authorize'
        end

        def token_credential_uri
          'https://auth.atlassian.com/oauth/token'
        end

        def authorization_uri(params)
          missing = missing_fields(params, %w[client_id])
          unless missing.blank?
            raise ConnectorsShared::ClientError.new("Missing required fields: #{missing.join(', ')}")
          end

          params[:response_type] = 'code'
          params[:additional_parameters] = { :prompt => 'consent', :audience => 'api.atlassian.com' }
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
          tokens = client.fetch_access_token
          tokens.merge(:cloud_id => fetch_cloud_id(tokens['access_token']))
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

        def oauth_scope
          %w[
            offline_access

            read:confluence-content.all
            read:confluence-content.summary
            read:confluence-props
            read:confluence-space.summary
            read:confluence-user
            readonly:content.attachment:confluence
            search:confluence
          ]
        end

        def missing_fields(params, required = [])
          Array.wrap(required).select { |field| params[field.to_sym].nil? }
        end

        private

        def fetch_cloud_id(access_token)
          response = HTTPClient.new.get(
            'https://api.atlassian.com/oauth/token/accessible-resources',
            nil,
            'Accept' => 'application/json',
            'Authorization' => "Bearer #{access_token}"
          )
          raise 'unable to fetch cloud id' unless HTTP::Status.successful?(response.status)
          json = JSON.parse(response.body)

          site = json.find { |sites| sites['url'] == 'https://workplace-search.atlassian.net' } || {}
          site.fetch('id') { raise 'unable to fetch cloud id' }
        end
      end
    end
  end
end
