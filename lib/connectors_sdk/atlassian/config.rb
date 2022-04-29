#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/config'

module ConnectorsSdk
  module Atlassian
    class Config < ConnectorsSdk::Base::Config
      attr_reader :base_url

      def initialize(cursors:, base_url:, index_permissions:)
        super(:cursors => cursors, :index_permissions => index_permissions)
        @base_url = base_url
      end

      def to_h
        super.merge(:base_url => base_url)
      end
    end
  end
end
