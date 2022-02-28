#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'faraday'
require 'httpclient'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/deep_dup'
require 'connectors_shared'
require 'date'
require 'active_support/all'

module Connectors
  module Base
    class CustomClient
      attr_reader :base_url, :middleware, :ensure_fresh_auth

      MAX_RETRIES = 5

      def initialize(base_url: nil, ensure_fresh_auth: nil)
        @base_url = base_url
        @ensure_fresh_auth = ensure_fresh_auth
        middleware!
      end

      def middleware!
        @middleware = Array.wrap(additional_middleware)
        @middleware += Array.wrap(default_middleware)
        @middleware.compact!
      end

      def additional_middleware
        [] # define as needed in subclass
      end

      def default_middleware
        [[Faraday::Request::Retry, retry_config]]
      end

      def retry_config
        {
          :retry_statuses => [429],
          :backoff_factor => 2,
          :max => MAX_RETRIES,
          :interval => 0.05
        }
      end

      [
        :delete,
        :get,
        :head,
        :options,
        :patch,
        :post,
        :put,
      ].each do |http_verb|
        define_method http_verb do |*args, &block|
          ensure_fresh_auth.call(self) if ensure_fresh_auth.present?
          http_client.public_send(http_verb, *args, &block)
        end
      end

      def http_client!
        @http_client = nil
        http_client
      end

      def http_client
        @http_client ||= Faraday.new(base_url) do |faraday|
          middleware.each do |middleware_config|
            faraday.use(*middleware_config)
          end

          faraday.adapter(:httpclient)
        end
      end

      private

      # https://github.com/lostisland/faraday/blob/b09c6db31591dd1a58fffcc0979b0c7d96b5388b/lib/faraday/connection.rb#L171
      METHODS_WITH_BODY = [:post, :put, :patch].freeze

      def send_body?(method)
        METHODS_WITH_BODY.include?(method.to_sym)
      end

      def request_with_throttling(method, url, options = {})
        response =
          if send_body?(method)
            public_send(method, url, options[:body], options[:headers])
          else
            public_send(method, url, options[:params], options[:headers])
          end

        if response.status == 429
          retry_after = response.headers['Retry-After']
          multiplier = options.fetch(:retry_mulitplier, 1)
          retry_after_secs = (retry_after.is_a?(Array) ? retry_after.first.to_i : retry_after.to_i) * multiplier
          retry_after_secs = 60 if retry_after_secs <= 0
          ConnectorsShared::Logger.warn("Exceeded #{self.class} request limits. Going to sleep for #{retry_after_secs} seconds")
          raise ConnectorsShared::ThrottlingError.new(:suspend_until => DateTime.now + retry_after_secs.seconds, :cursors => options[:cursors])
        else
          response
        end
      end
    end
  end
end
