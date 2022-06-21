#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'elasticsearch'
require 'connectors_app/config'

module ConnectorsShared
  class ElasticsearchClient
    class << self

      def health
        client.cluster.health
      end

    private
      def client
        @client ||= Elasticsearch::Client.new(connection_configs)
      end

      def connection_configs
        es_config = ConnectorsApp::Config['elasticsearch']
        configs = { :api_key => es_config['api_key'] }
        if es_config['cloud_id']
          configs[:cloud_id] = es_config['cloud_id']
        elsif es_config['hosts']
          configs[:hosts] = es_config['hosts']
        else
          raise 'Either elasitcsearch.cloud_id or elasticsearch.hosts should be configured.'
        end
        configs
      end
    end
  end
end
