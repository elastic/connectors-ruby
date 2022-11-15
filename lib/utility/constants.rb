#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Utility
  class Constants
    THUMBNAIL_FIELDS = %w[_thumbnail_80x100 _thumbnail_310x430].freeze
    SUBEXTRACTOR_RESERVED_FIELDS = %w[_subextracted_as_of _subextracted_version].freeze
    ALLOW_FIELD = '_allow_permissions'
    DENY_FIELD = '_deny_permissions'
    CONNECTORS_INDEX = '.elastic-connectors'
    JOB_INDEX = '.elastic-connectors-sync-jobs'
    CONTENT_INDEX_PREFIX = 'search-'
    CRAWLER_SERVICE_TYPE = 'elastic-crawler'
    FILTERING_RULES_FEATURE = 'filtering_rules'
    FILTERING_ADVANCED_FEATURE = 'filtering_advanced_config'

    # Maximum number of operations in BULK Elasticsearch operation that will ingest the data
    DEFAULT_MAX_INGESTION_QUEUE_SIZE = 500
    # Maximum size of either whole BULK Elasticsearch operation or one document in it
    DEFAULT_MAX_INGESTION_QUEUE_BYTES = 5 * 1024 * 1024
  end
end
