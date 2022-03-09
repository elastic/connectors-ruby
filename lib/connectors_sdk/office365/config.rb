#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/config'

module ConnectorsSdk
  module Office365
    class Config < ConnectorsSdk::Base::Config
      ALL_DRIVE_IDS = 'all'.freeze

      attr_reader :drive_ids, :index_permissions

      def initialize(drive_ids:, cursors:, index_permissions: false)
        super(:cursors => cursors)
        @drive_ids = drive_ids
        @index_permissions = index_permissions
      end

      def index_all_drives?
        drive_ids == ALL_DRIVE_IDS
      end

      def to_h
        super.merge(
          :drive_ids => drive_ids,
          :index_permissions => index_permissions
        )
      end
    end
  end
end
