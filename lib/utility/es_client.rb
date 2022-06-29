#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'elasticsearch'
require 'app/config'

module Utility
  class EsClient
    class << self
      def method_missing(m, *args, &block)
        client.send(m, *args, &block)
      end

      def respond_to_missing?(m, include_all = false)
        client.respond_to?(m, include_all)
      end

      private

      def client
        @client ||= Elasticsearch::Client.new(connection_configs)
      end

      def connection_configs
        es_config = App::Config['elasticsearch']
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
