#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'connectors_sdk/base/config'

module ConnectorsSdk
  module GitLab
    class Config < ConnectorsSdk::Base::Config
      attr_reader :base_url, :api_token

      def initialize(cursors:, base_url:, api_token:)
        @base_url = base_url
        @api_token = api_token
        super(cursors)
      end

      def to_h
        super.to_h.merge(
          :base_url => @base_url,
          :api_token => api_token
        )
      end
    end
  end
end
