#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Connectors
  class SyncStatus
    COMPLETED = 'completed'
    IN_PROGRESS = 'in_progress'
    ERROR = 'error'

    STATUSES = [
      COMPLETED,
      IN_PROGRESS,
      ERROR
    ]
  end
end
