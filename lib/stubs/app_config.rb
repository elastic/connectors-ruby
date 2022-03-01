#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'logger'

class AppConfig
  class << self
    def connectors_logger
      Logger.new(STDOUT)
    end

    def connectors
      ConnectorsConfig
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

    def content_source_sync_thumbnails_enabled?
      true
    end
  end
end

class ConnectorsConfig
  class << self
    def config
      {
        'transient_server_error_retry_delay_minutes' => 5
      }
    end
  end
end
