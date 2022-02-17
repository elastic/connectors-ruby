#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'logger'
require 'java'

java_package 'co.elastic.connectors.stubs'
class AppConfig
  class << self
    def connectors_logger
      Logger.new(STDOUT)
    end

    def content_source_sync_max_errors
      1000
    end

    def content_source_sync_max_consecutive_errors
      10
    end

    def content_source_sync_max_error_ratio
      0.15
    end

    def content_source_sync_error_ratio_window_size
      100
    end
  end
end
