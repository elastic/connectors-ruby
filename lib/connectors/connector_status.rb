#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Connectors
  class ConnectorStatus
    CREATED             = 'created'
    NEEDS_CONFIGURATION = 'needs_configuration'
    CONFIGURED          = 'configured'
    CONNECTED           = 'connected'
    ERROR               = 'error'

    STATUSES = [
      CREATED,
      NEEDS_CONFIGURATION,
      CONFIGURED,
      CONNECTED,
      ERROR
    ]

    STATUSES_ALLOWING_SYNC = [
      CONFIGURED,
      CONNECTED,
      ERROR
    ]
  end
end
