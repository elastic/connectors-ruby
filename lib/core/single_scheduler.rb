#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'time'
require 'fugit'
require 'core/connector_settings'
require 'core/scheduler'
require 'utility/cron'
require 'utility/logger'
require 'utility/exception_tracking'

module Core
  class SingleScheduler < Core::Scheduler
    def initialize(connector_id, poll_interval)
      super(poll_interval)
      @connector_id = connector_id
    end

    def connector_ids
      [@connector_id]
    end
  end
end
