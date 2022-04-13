# frozen_string_literal: true

module ConnectorsSdk
  module Atlassian
    class Config < ConnectorsSdk::Base::Config
      attr_reader :base_url, :index_permissions

      def initialize(cursors:, base_url:, index_permissions: false)
        super(:cursors => cursors)
        @base_url = base_url
        @index_permissions = index_permissions
      end

      def to_h
        super.merge(:base_url => base_url)
      end
    end
  end
end
