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
    API_BASE_URL = App::Config['gitlab']['api_base_url'] || 'https://gitlab.com/api/v4'
    API_TOKEN = App::Config['gitlab']['api_token']

    class CustomClient < Connectors::Base::CustomClient
      class ClientError < StandardError
        attr_reader :status_code, :endpoint

        def initialize(status_code, endpoint)
          @status_code = status_code
          @endpoint = endpoint
        end
      end

      def initialize(base_url:, api_token: API_TOKEN, ensure_fresh_auth: nil)
        @api_token = api_token
        super(:base_url => base_url || API_BASE_URL, :ensure_fresh_auth => ensure_fresh_auth)
      end

      def additional_middleware
        [
          ::FaradayMiddleware::FollowRedirects,
          [Utility::Middleware::RestrictHostnames, { :allowed_hosts => [base_url, API_BASE_URL] }],
          [Utility::Middleware::BearerAuth, { :bearer_auth_token => API_TOKEN }]
        ]
      end
    end
  end
end
