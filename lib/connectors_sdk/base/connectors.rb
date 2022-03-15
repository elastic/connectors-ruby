#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module ConnectorsSdk
  module Base
    class Connectors
      attr_reader :connectors

      def self.factory
        @@factory ||= new # rubocop:disable Style/ClassVars
      end

      def initialize
        @connectors = {}
      end

      def to_h
        {
          :connectors => connectors,
          :params => params
        }
      end

      def register(name, klass)
        @connectors[name] = klass
      end

      def connector(name)
        @connectors[name].new
      end
    end

    # loading plugins (might replace this with a directory scan)
    require_relative '../share_point/http_call_wrapper'

    ConnectorsSdk::Base::Connectors.factory.register(ConnectorsSdk::SharePoint::NAME, ConnectorsSdk::SharePoint::HttpCallWrapper)
  end
end
