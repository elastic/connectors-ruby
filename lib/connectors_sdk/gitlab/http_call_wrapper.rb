#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/gitlab/config'
require 'connectors_sdk/gitlab/custom_client'

module ConnectorsSdk
  module GitLab
    class HttpCallWrapper < ConnectorsSdk::Base::HttpCallWrapper
      SERVICE_TYPE = 'gitlab'

      def name
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

      def client(params)
        ConnectorsSdk::GitLab::CustomClient.new(
          :base_url => params[:base_url] || ConnectorsSdk::GitLab::API_BASE_URL,
          :api_token => params[:api_token]
        )
      end

      def health_check(_params)
        # let's do a simple call
        response = client(_params).get('user')
        response.present? && response.status == 200
      end

      def document_batch(_params)
        query_params = {
          :simple => 1,
          :pagination => :keyset,
          :per_page => 100, # max
          :order_by => :id,
          :sort => :desc
        }
        results_list = JSON.parse(client(_params).get('projects', { :params => query_params }).body)
        # for now let's just take one page
        [
          Hashie::Mash.new({ :results => results_list }),
          {},  # not passing the cursors yet
          true # we're saying it's the last page
        ]
      end

      def deleted(_params)
        []
      end

      def permissions(_params)
        []
      end
    end
  end
end
