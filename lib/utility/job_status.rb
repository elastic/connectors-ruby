#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

module Utility
  class JobStatus
    CREATED = 'created'
    RUNNING = 'running'
    FINISHED = 'finished'
    FAILED = 'failed'

    def self.is_valid?(status)
      [CREATED, RUNNING, FINISHED, FAILED].include? status
    end
  end
end
