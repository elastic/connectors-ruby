#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/authorization'

module ConnectorsSdk
  module ConfluenceCloud
    class Authorization < ConnectorsSdk::Base::Authorization
      class << self
        def access_token(params)
          tokens = super
          tokens.merge(:cloud_id => fetch_cloud_id(tokens['access_token'], params[:external_connector_base_url]))
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

        private

        def authorization_url
          'https://auth.atlassian.com/authorize'
        end

        def token_credential_uri
          'https://auth.atlassian.com/oauth/token'
        end

        def additional_parameters
          { :prompt => 'consent', :audience => 'api.atlassian.com' }
        end

        def fetch_cloud_id(access_token, base_url)
          response = HTTPClient.new.get(
            'https://api.atlassian.com/oauth/token/accessible-resources',
            nil,
            'Accept' => 'application/json',
            'Authorization' => "Bearer #{access_token}"
          )
          raise 'unable to fetch cloud id' unless HTTP::Status.successful?(response.status)
          json = JSON.parse(response.body)

          site = json.find { |sites| sites['url'] == base_url } || {}
          site.fetch('id') { raise 'unable to fetch cloud id' }
        end
      end
    end
  end
end
