#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/connector'
require 'connectors/gitlab/custom_client'
require 'connectors/gitlab/adapter'
require 'connectors/gitlab/config'
require 'connectors/gitlab/extractor'
require 'rack/utils'

module Connectors
  module GitLab
    class Connector < Connectors::Base::Connector
      SERVICE_TYPE = 'gitlab'

      def display_name
        'GitLab Connector'
      end

      def configurable_fields
        [
          {
            'key' => 'api_token',
            'label' => 'API Token'
          },
          {
            'key' => 'base_url',
            'label' => 'Base URL'
          }
        ]
      end

      private

      def client(params)
        Connectors::GitLab::CustomClient.new(
          :base_url => params[:base_url] || Connectors::GitLab::API_BASE_URL,
          :api_token => params[:api_token]
        )
      end

      def config(params)
        Connectors::GitLab::Config.new(
          :cursors => params.fetch(:cursors, {}) || {},
          :index_permissions => params.fetch(:index_permissions, false)
        )
      end

      def extractor_class
        Connectors::GitLab::Extractor
      end

      def custom_client_error
        Connectors::GitLab::CustomClient::ClientError
      end

      def health_check(params)
        # let's do a simple call
        response = client(params).get('user')
        unless response.present? && response.status == 200
          raise "Health check failed with response status #{response.status} and body #{response.body}"
        end
      end
    end
  end
end
