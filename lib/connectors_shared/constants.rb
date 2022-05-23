#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module ConnectorsShared
  class Constants
    THUMBNAIL_FIELDS = %w[_thumbnail_80x100 _thumbnail_310x430].freeze
    SUBEXTRACTOR_RESERVED_FIELDS = %w[_subextracted_as_of _subextracted_version].freeze
    ALLOW_FIELD = '_allow_permissions'.freeze
    DENY_FIELD = '_deny_permissions'.freeze

    # The following section reads as following:
    # The job will extract documents until the job queue size will reach
    # JOB_QUEUE_SIZE_IDLE_THRESHOLD items. After that, the job will attempt to sleep
    # for IDLE_SLEEP_TIME seconds and check the queue size again. If the queue is still
    # full, it will sleep for maximum MAX_IDDLE_ATTEMPTS times, and if the queue is still
    # full, then job will be terminated.
    JOB_QUEUE_SIZE_IDLE_THRESHOLD = 500 # How many documents the job queue stores until it sleeps
    IDLE_SLEEP_TIME = 10 # For how long job queue will sleep before checking the queue size again
    MAX_IDLE_ATTEMPTS = 30 # How many consecutive times job will try to sleep until it's destroyed
  end
end
