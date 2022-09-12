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
    class InvalidConfigurationError < StandardError; end

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

      def initialize(local_configuration: {}, remote_configuration: {})
        super

        raise InvalidConfigurationError.new("Configuration section \"#{self.class.service_type}\" is required but not provided.") unless local_configuration

        @extractor = Connectors::GitLab::Extractor.new(
          :base_url => remote_configuration.dig(:base_url, :value),
          :api_token => local_configuration[:api_token]
        )
      end

      def yield_documents
        next_page_link = nil
        loop do
          next_page_link = @extractor.yield_projects_page(next_page_link) do |projects_chunk|
            projects_chunk.each do |project|
              yield Connectors::GitLab::Adapter.to_es_document(:project, project)
            end
          end
          break unless next_page_link.present?
        end
      end

      private

      def do_health_check
        @extractor.health_check
      end
    end
  end
end
