#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'active_support/core_ext/hash/indifferent_access'

require 'connectors/base/connector'
require 'connectors/gitlab/extractor'
require 'connectors/gitlab/custom_client'
require 'connectors/gitlab/adapter'
require 'core/output_sink'

module Connectors
  module GitLab
    class Connector < Connectors::Base::Connector
      def self.service_type
        'gitlab'
      end

      def self.display_name
        'GitLab Connector'
      end

      def self.configurable_fields
        {
          :base_url => {
            :label => 'Base URL',
            :value => Connectors::GitLab::DEFAULT_BASE_URL
          }
        }
      end

      def initialize(local_configuration: {}, connector_settings: {})
        super

        @extractor = Connectors::GitLab::Extractor.new(
          :base_url => connector_settings.configuration[:base_url][:value],
          :api_token => @local_configuration[:api_token]
        )
      end

      def yield_documents
        yield_projects do |projects_chunk|
          projects_chunk.each do |project|
            yield Connectors::GitLab::Adapter.to_es_document(:project, project)

            yield_project_files(projects_chunk) do |files|
              files.each do |file|
                yield Connectors::GitLab::Adapter.to_es_document(:file, file)
              end
            end
          end
        end
      end

      private

      def health_check(_params)
        @extractor.health_check
      end

      def custom_client_error
        Connectors::GitLab::CustomClient::ClientError
      end

      def yield_projects(&block)
        next_page_link = nil
        loop do
          next_page_link = @extractor.yield_projects_page(next_page_link, &block)
          break unless next_page_link.present?
        end
      end

      def yield_project_files(projects_chunk)
        projects_chunk.each_with_index do |project, idx|
          project = project.with_indifferent_access

          chunk_size = projects_chunk.size
          Utility::Logger.info("Fetching files for project #{project[:id]} (#{idx + 1} out of #{chunk_size})...")

          files = @extractor.fetch_project_repository_files(project[:id])

          yield files
        end
      end
    end
  end
end
