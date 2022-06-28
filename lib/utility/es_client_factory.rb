#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'elasticsearch'
require 'app/config'

module Utility
  class EsClientFactory
    class << self
      def client(index_name = nil)
        Elasticsearch::Client.new(connection_configs(index_name))
      end

      private

      def connection_configs(index_name)
        es_config = App::Config['elasticsearch']
        index_name = es_config['api_keys'].keys.first if index_name.nil? || index_name.empty?
        api_key = es_config['api_keys'][index_name]
        raise "No API key found for index '#{index_name}'" if api_key.nil? || api_key.empty?
        configs = { :api_key => api_key }

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
