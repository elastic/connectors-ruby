#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Connectors
  class SyncStatus
    PENDING     = 'pending'
    IN_PROGRESS = 'in_progress'
    CANCELING   = 'canceling'
    CANCELED    = 'canceled'
    SUSPENDED   = 'suspended'
    COMPLETED   = 'completed'
    ERROR       = 'error'

    STATUSES = [
      PENDING,
      IN_PROGRESS,
      CANCELING,
      CANCELED,
      SUSPENDED,
      COMPLETED,
      ERROR
    ]

    PENDING_STATUES = [
      PENDING,
      SUSPENDED
    ]

    TERMINAL_STATUSES = [
      CANCELED,
      COMPLETED,
      ERROR
    ]
  end
end
