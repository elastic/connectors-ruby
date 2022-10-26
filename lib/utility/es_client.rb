#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'logger'
require 'elasticsearch'
require 'elasticsearch/api'
require 'elasticsearch/api/namespace/common'
require 'elasticsearch/api/utils'
require 'elasticsearch/api/response'

module Utility
  class EsClient < ::Elasticsearch::Client
    class IndexingFailedError < StandardError
      def initialize(message, error = nil)
        super(message)
        @cause = error
      end

      attr_reader :cause
    end

    def initialize(es_config, &block)
      super(connection_configs(es_config), &block)
    end

    def connection_configs(es_config)
      configs = {}
      configs[:api_key] = es_config[:api_key] if es_config[:api_key]
      if es_config[:cloud_id]
        configs[:cloud_id] = es_config[:cloud_id]
      elsif es_config[:hosts]
        configs[:hosts] = es_config[:hosts]
      else
        raise 'Either elasticsearch.cloud_id or elasticsearch.hosts should be configured.'
      end
      configs[:retry_on_failure] = es_config[:retry_on_failure] || false
      configs[:request_timeout] = es_config[:request_timeout] || nil
      configs[:log] = es_config[:log] || false
      configs[:trace] = es_config[:trace] || false

      # transport options
      configs[:transport_options] = es_config[:transport_options] if es_config[:transport_options]
      configs[:ca_fingerprint] = es_config[:ca_fingerprint] if es_config[:ca_fingerprint]

      # if log or trace is activated, we use the application logger
      configs[:logger] = if configs[:log] || configs[:trace]
                           Utility::Logger.logger
                         else
                           # silence!
                           ::Logger.new(IO::NULL)
                         end
      configs
    end

    def bulk(arguments = {})
      raise_if_necessary(patched_bulk(arguments))
    end

    private

    # This method is a copy of a method from original Elasticsearch client from here:
    # https://github.com/elastic/elasticsearch-ruby/blob/8.5/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb#L43
    # Small (or not so small) problem for us was that the original method clones the arguments.
    # Sometimes our bulk payload is pretty big and .clone on arguments essentially doubles the amount of memory
    # that is needed to ingest the data. In our case it's an important thing, thus we copy-pasted the method here
    # and removed the .clone call.
    # It produces some overhead for us when updating `elasticsearch` gem - we should check that this function did not change
    # but it seems like a small price to pay for memory usage reduction.
    def patched_bulk(arguments = {})
      headers = arguments.delete(:headers) || {}

      body = arguments.delete(:body)

      index = arguments.delete(:index)

      method = ::Elasticsearch::API::HTTP_POST
      path = if index
               "#{Utils.__listify(index)}/_bulk"
             else
               '_bulk'
             end
      params = ::Elasticsearch::API::Utils.process_params(arguments)

      payload = if body.is_a? Array
                  ::Elasticsearch::API::Utils.__bulkify(body)
                else
                  body
                end

      headers['Content-Type'] = 'application/x-ndjson'
      ::Elasticsearch::API::Response.new(
        perform_request(method, path, params, payload, headers)
      )
    end

    def raise_if_necessary(response)
      if response['errors']
        first_error = nil

        response['items'].each do |item|
          %w[index delete].each do |op|
            if item.has_key?(op) && item[op].has_key?('error')
              first_error = item

              break
            end
          end
        end

        if first_error
          trace_id = Utility::Logger.generate_trace_id
          Utility::Logger.error("Failed to index documents into Elasticsearch. First error in response is: #{first_error.to_json}")
          short_message = Utility::Logger.abbreviated_message(first_error.to_json)
          raise IndexingFailedError.new("Failed to index documents into Elasticsearch with an error '#{short_message}'. Look up the error ID [#{trace_id}] in the application logs to see the full error message.")
        else
          raise IndexingFailedError.new('Failed to index documents into Elasticsearch due to unknown error. Try enabling tracing for Elasticsearch and checking the logs.')
        end
      end
      response
    end
  end
end
