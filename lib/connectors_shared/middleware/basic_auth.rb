#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module ConnectorsShared
  module Middleware
    class BasicAuth
      AUTHORIZATION = 'Authorization'

      attr_reader :basic_auth_token

      def initialize(app = nil, options = {})
        @app = app
        @basic_auth_token = options.fetch(:basic_auth_token)
      end

      def call(env)
        env.request_headers[AUTHORIZATION] = "Basic #{basic_auth_token}"
        @app.call(env)
      end
    end
  end
end
