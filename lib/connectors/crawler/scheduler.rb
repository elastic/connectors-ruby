#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/scheduler'
require 'core/connector_settings'
require 'core/elastic_connector_actions'
require 'utility/logger'
require 'utility/exception_tracking'

module Connectors
  module Crawler
    class Scheduler < Core::Scheduler
      def connector_settings
        Core::ConnectorSettings.fetch_crawler_connectors || []
      rescue StandardError => e
        Utility::ExceptionTracking.log_exception(e, 'Could not retrieve Crawler connectors due to unexpected error.')
        []
      end

      private

      def connector_registered?(service_type)
        service_type == 'elastic-crawler'
      end
    end
  end
end
