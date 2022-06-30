#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'faraday_middleware/response/follow_redirects'
require 'connectors/base/custom_client'
require 'utility/middleware/bearer_auth'
require 'utility/middleware/basic_auth'
require 'utility/middleware/restrict_hostnames'

require 'app/config'

module Connectors
  module GitLab
    DEFAULT_BASE_URL = 'https://gitlab.com/api/v4'

    class CustomClient < Connectors::Base::CustomClient
      attr_reader :api_token

      class ClientError < StandardError
        attr_reader :status_code, :endpoint, :api_token

        def initialize(status_code, endpoint)
          @status_code = status_code
          @endpoint = endpoint
        end
      end

      def initialize(base_url:, api_token:, ensure_fresh_auth: nil)
        @api_token = api_token
        super(:base_url => base_url || DEFAULT_BASE_URL, :ensure_fresh_auth => ensure_fresh_auth)
      end

      def additional_middleware
        [
          ::FaradayMiddleware::FollowRedirects,
          [Utility::Middleware::RestrictHostnames, { :allowed_hosts => [base_url, DEFAULT_BASE_URL] }],
          [Utility::Middleware::BearerAuth, { :bearer_auth_token => api_token }]
        ]
      end
    end
  end
end
