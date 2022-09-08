#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Utility
  class Constants
    THUMBNAIL_FIELDS = %w[_thumbnail_80x100 _thumbnail_310x430].freeze
    SUBEXTRACTOR_RESERVED_FIELDS = %w[_subextracted_as_of _subextracted_version].freeze
    ALLOW_FIELD = '_allow_permissions'.freeze
    DENY_FIELD = '_deny_permissions'.freeze
    CONNECTORS_INDEX = '.elastic-connectors'.freeze
    JOB_INDEX = '.elastic-connectors-sync-jobs'.freeze
  end
end
