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
require 'utility/sink'

module Connectors
  module GitLab
    class Connector < Connectors::Base::Connector
      SERVICE_TYPE = 'gitlab'

      def initialize(params)
        super()
        @extractor = Connectors::GitLab::Extractor.new
        @sinks = [Utility::Sink::ConsoleSink.new]
        # if index name is specified, we need an elastic sink
        if params.present? && params[:index_name].present?
          elastic_sink = Utility::Sink::ElasticSink.new
          elastic_sink.index_name = params[:index_name]
          @sinks.push(elastic_sink)
        end
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

      def sync_content(_params = {})
        extract_projects
      end

      def deleted(_params = {})
        []
      end

      def permissions(_params = {})
        []
      end

      private

      def health_check(_params)
        @extractor.health_check
      end

      def custom_client_error
        Connectors::GitLab::CustomClient::ClientError
      end

      def ingest_documents(docs)
        @sinks.each { |sink| sink.ingest_multiple(docs) }
      end

      def extract_projects
        next_page_link = nil
        loop do
          next_page_link = @extractor.yield_projects_page(next_page_link) do |projects_chunk|
            projects = projects_chunk.map { |p| Connectors::GitLab::Adapter.to_es_document(:project, p) }
            ingest_documents(projects)
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
          files = files.map { |file| Connectors::GitLab::Adapter.to_es_document(:file, file) }
          project[:files] = files
          ingest_documents(files)
        end
      rescue StandardError => e
        puts(e.message)
        puts(e.backtrace)
        raise e
      end
    end
  end
end
