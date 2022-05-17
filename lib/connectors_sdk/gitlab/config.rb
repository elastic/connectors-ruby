#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/config'

module ConnectorsSdk
  module GitLab
    class Config < ConnectorsSdk::Base::Config
      attr_reader :index_permissions

      def initialize(cursors:, index_permissions: false)
        super(:cursors => cursors)
        @index_permissions = index_permissions || false
      end

      def to_h
        super.merge(:index_permissions => index_permissions)
      end
    end
  end
end
