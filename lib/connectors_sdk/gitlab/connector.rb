#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'active_support/core_ext/hash/indifferent_access'

require 'connectors_sdk/base/connector'
require 'connectors_sdk/gitlab/extractor'
require 'connectors_sdk/utility/sink'

module ConnectorsSdk
  module GitLab
    class Connector < ConnectorsSdk::Base::Connector
      SERVICE_TYPE = 'gitlab'

      def initialize
        super
        @extractor = ConnectorsSdk::GitLab::Extractor.new
        @sink = Utility::Sink::ConsoleSink.new
      end

      def display_name
        'GitLab Connector'
      end

      def configurable_fields
        [
          {
            'key' => 'base_url',
            'label' => 'Base URL'
          },
          {
            'key' => 'api_token',
            'label' => 'API Token'
          }
        ]
      end

      def health_check(_params)
        true
      end

      def sync_content(_params)
        puts 'Starting content synchronization...'
        extract_projects
      end

      def deleted(_params)
        []
      end

      def permissions(_params)
        []
      end

      private

      def extract_projects
        next_page_link = nil
        loop do
          next_page_link = @extractor.yield_projects_page(next_page_link) do |projects_chunk|
            @sink.ingest_multiple(projects_chunk)
            extract_project_files(projects_chunk)
          end
          break unless next_page_link.present?
        end
      rescue StandardError => e
        puts(e.message)
        puts(e.backtrace)
        raise e
      end

      def extract_project_files(projects_chunk)
        projects_chunk.each_with_index do |project, idx|
          project = project.with_indifferent_access
          files = @extractor.fetch_project_repository_files(project[:id])
          chunk_size = projects_chunk.size
          puts("Fetching files for project #{project[:id]} (#{idx + 1} out of #{chunk_size})...")
          project[:files] = files
        end
        @sink.ingest_multiple(projects_chunk)
      rescue StandardError => e
        puts(e.message)
        puts(e.backtrace)
        raise e
      end
    end
  end
end
