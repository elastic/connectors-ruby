#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Connectors
  module Base
    class Config
      attr_reader :cursors

      def initialize(cursors:)
        @cursors = cursors || {}
      end

      def to_h
        {
          :cursors => cursors
        }
      end
    end
  end
end
