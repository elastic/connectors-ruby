#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module ConnectorsSdk
  module Base
    class Config
      attr_reader :cursors, :index_permissions

      def initialize(cursors:, index_permissions: false)
        @cursors = cursors || {}
        @index_permissions = index_permissions
      end

      def to_h
        {
          :cursors => cursors,
          :index_permissions => index_permissions
        }
      end

      def overwrite_cursors!(new_cursors)
        @cursors = new_cursors
      end
    end
  end
end
