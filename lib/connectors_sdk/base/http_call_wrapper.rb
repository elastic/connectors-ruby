#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module ConnectorsSdk
  module Base
    class HttpCallWrapper
      def describe
        {
          :name => name,
          :is_oauth => is_oauth,
          :configurable_fields => configurable_fields
        }
      end

      def is_oauth
        false
      end

      def configurable_fields
        []
      end
    end
  end
end
