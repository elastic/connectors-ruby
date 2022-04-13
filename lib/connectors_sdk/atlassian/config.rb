# frozen_string_literal: true
require_relative '../base/config'

module ConnectorsSdk
  module Atlassian
    class Config < ConnectorsSdk::Base::Config
      attr_reader :base_url

      def initialize(cursors:, base_url:, index_permissions: false)
        super(:cursors => cursors, :index_permissions => index_permissions)
        @base_url = base_url
      end

      def to_h
        super.merge(
          :base_url => base_url
        )
      end
    end
  end
end
