#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'faraday/middleware'
require 'resolv'

module ConnectorsShared
  module Middleware
    class RestrictHostnames < Faraday::Middleware
      class AddressNotAllowed < ConnectorsShared::ClientError; end
      URL_PATTERN = /\Ahttp/

      attr_reader :allowed_hosts, :allowed_ips

      def initialize(app = nil, options = {})
        super(app)
        @allowed_hosts = options[:allowed_hosts]
        @allowed_ips = ips_from_hosts(@allowed_hosts)
      end

      def call(env)
        raise AddressNotAllowed.new("Address not allowed for #{env[:url]}") if denied?(env)
        @app.call(env)
      end

      private

      def ips_from_hosts(hosts)
        hosts&.flat_map do |host|
          if URL_PATTERN.match(host)
            lookup_ips(URI.parse(host).host)
          elsif Resolv::IPv4::Regex.match(host) || Resolv::IPv6::Regex.match(host)
            IPAddr.new(host)
          else
            lookup_ips(host)
          end
        end || []
      end

      def denied?(env)
        requested_ips = lookup_ips(env[:url].hostname)
        no_match = requested_ips.all? { |ip| !@allowed_ips.include?(ip) }
        return false unless no_match
        ConnectorsShared::Logger.warn("Requested url #{env[:url]} with resolved ip addresses #{requested_ips} does not match " \
                                  "allowed hosts #{@allowed_hosts} with resolved ip addresses #{@allowed_ips}. Retrying.")
        @allowed_ips = ips_from_hosts(@allowed_hosts) # maybe the IP has changed for an allowed host. Re-do allowed_hosts DNS lookup
        no_match = requested_ips.all? { |ip| !@allowed_ips.include?(ip) }
        ConnectorsShared::Logger.error("Requested url #{env[:url]} with resolved ip addresses #{requested_ips} does not match " \
                                  "allowed hosts #{@allowed_hosts} with resolved ip addresses #{@allowed_ips}") if no_match
        no_match
      end

      def lookup_ips(hostname)
        addr_infos(hostname).map { |a| IPAddr.new(a.ip_address) }
      end

      def addr_infos(hostname)
        Addrinfo.getaddrinfo(hostname, nil, :UNSPEC, :STREAM)
      rescue SocketError
        # In case of invalid hostname, return an empty list of addresses
        []
      end
    end
  end
end
