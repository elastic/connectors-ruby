#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'faraday_middleware'
require 'connectors_shared/middleware/restrict_hostnames'
require 'connectors_shared/middleware/bearer_auth'
require 'connectors_sdk/base/custom_client'

module ConnectorsSdk
  module Atlassian
    class CustomClient < ConnectorsSdk::Base::CustomClient
      class ClientError < ConnectorsShared::ClientError
        attr_reader :url, :status_code, :message

        def initialize(url, status_code, message)
          super("Failed to call #{url} because #{status_code}: #{message}")
          @url = url
          @status_code = status_code
          @message = message
        end
      end
      class ServiceUnavailableError < ClientError; end
      class ContentConvertibleError < ClientError; end

      MEDIA_API_BASE_URL = 'https://api.media.atlassian.com'

      attr_reader :base_url, :access_token

      def initialize(base_url:, access_token:, ensure_fresh_auth: nil)
        @access_token = access_token
        super(:base_url => base_url, :ensure_fresh_auth => ensure_fresh_auth)
      end

      def default_middleware
        [] # Ignoring Base default for now, but we should probably revert to using Base default?
      end

      def additional_middleware
        [
            ::FaradayMiddleware::FollowRedirects,
            [ConnectorsShared::Middleware::RestrictHostnames, { :allowed_hosts => [base_url, MEDIA_API_BASE_URL] }],
            [ConnectorsShared::Middleware::BearerAuth, { :bearer_auth_token => @access_token }]
        ]
      end

      def update_auth_data!(new_access_token)
        @access_token = new_access_token
        middleware!
        http_client! # force a new client to pick up new middleware

        self
      end

      def download(url)
        response = get(url)
        unless HTTP::Status.successful?(response.status)
          raise ClientError.new(url, response.status, response.body)
        end
        response
      end

      private

      def parse_and_raise_if_necessary!(response)
        unless response.success?
          status_code = response.status.to_i
          atlassian_error_klass =
            if status_code == 504
              ServiceUnavailableError
            elsif status_code == 400 && response.body.include?('is not ContentConvertible or API available')
              ContentConvertibleError
            else
              ClientError
            end
          raise atlassian_error_klass.new(response.env.url.to_s, status_code, response.body)
        end
        JSON.parse(response.body)
      end
    end
  end
end
