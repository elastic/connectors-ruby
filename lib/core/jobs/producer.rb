#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Core
  module Jobs
    class Producer
      JOB_TYPES = %i(sync).freeze

      class << self
        def enqueue_job(job_type:, connector_settings:)
          raise UnsupportedJobType unless JOB_TYPES.include?(job_type)
          raise ArgumentError unless connector_settings.kind_of?(ConnectorSettings)

          ElasticConnectorActions.create_job(connector_settings: connector_settings)
        end
      end
    end

    class UnsupportedJobType < StandardError; end
  end
end
