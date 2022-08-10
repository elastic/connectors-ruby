#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'hashie'
require 'json'
require 'rack/utils'
require 'active_support/core_ext/hash/indifferent_access'
require 'connectors/gitlab/custom_client'

module Connectors
  module GitLab
    class Extractor
      PAGE_SIZE = 100 # max is 100

      def initialize(base_url: nil, api_token: nil, owned_only: true)
        super()
        @base_url = base_url
        @api_token = api_token
        # only get projects that user owns
        @owned_only = owned_only
      end

      def yield_projects_page(next_page_link = nil)
        query_params = {
          :pagination => :keyset,
          :per_page => PAGE_SIZE,
          :order_by => :id,
          :sort => :desc,
          :owned => @owned_only
        }

        if next_page_link.present?
          if (matcher = /(https?:[^>]*)/.match(next_page_link))
            clean_query = URI.parse(matcher.captures[0]).query
            query_params = Rack::Utils.parse_query(clean_query)
          else
            raise "Next page link has unexpected format: #{next_page_link}"
          end
        end
        response = client.get('projects', query_params)

        projects_chunk = JSON.parse(response.body)
        yield projects_chunk

        # return next link
        response.headers['Link'] || nil
      end

      def health_check
        # let's do a simple call to get the current user
        response = client.get('user')
        unless response.present? && response.status == 200
          raise "Health check failed with response status #{response.status} and body #{response.body}"
        end
      end

      private

      def client
        @client ||= Connectors::GitLab::CustomClient.new(base_url: @base_url, api_token: @api_token)
      end
    end
  end
end
