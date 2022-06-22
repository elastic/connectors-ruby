#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'hashie'
require 'rack/utils'
require 'active_support/core_ext/hash/indifferent_access'
require 'connectors_sdk/gitlab/custom_client'


module ConnectorsSdk
  module GitLab
    class Extractor
      PAGE_SIZE = 100 # max is 100

      def yield_projects
        query_params = {
          :pagination => :keyset,
          :per_page => PAGE_SIZE,
          :order_by => :id,
          :sort => :desc
        }

        next_page_link = nil

        10.times do
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

          next_page_link = response.headers['Link'] || nil
          break unless next_page_link.present?
        end
      end

      def fetch_project_repository_files(project_id)
        response = client.get("projects/#{project_id}/repository/tree")
        if response.status != 200
          puts "Received #{response.status} status when fetching repository files for project #{project_id}"
          return []
        end
        files = JSON.parse(response.body)

        files.map { |file| file['path'] }
      end

      private

      def client
        @client ||= ConnectorsSdk::GitLab::CustomClient.new(base_url: 'https://gitlab.com/api/v4')
      end
    end
  end
end
