#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/confluence/custom_client'

module ConnectorsSdk
  module ConfluenceCloud
    class CustomClient < ConnectorsSdk::Confluence::CustomClient
      def user_groups(account_id, limit: 200, start: 0)
        size = Float::INFINITY

        groups = []

        while start + limit < size
          params = {
            :start => start,
            :limit => limit,
            :accountId => account_id
          }
          response = get('rest/api/user/memberof', params)
          result = Hashie::Mash.new(parse_and_raise_if_necessary!(response))
          size = result.size
          start += limit
          groups.concat(result.results)
        end

        groups
      end

      def user(account_id, expand: [])
        params = {
          :accountId => account_id
        }
        if expand.present?
          params[:expand] = case expand
                            when Array
                              expand.join(',')
                            when String
                              expand
                            else
                              expand.to_s
                            end
        end
        response = get('rest/api/user', params)
        Hashie::Mash.new(parse_and_raise_if_necessary!(response))
      rescue ConnectorsSdk::Atlassian::CustomClient::ClientError => e
        if e.status_code == 404
          ConnectorsShared::Logger.warn("Could not find a user with account id #{account_id}")
          nil
        else
          raise
        end
      end
    end
  end
end
