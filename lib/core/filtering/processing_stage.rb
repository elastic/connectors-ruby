#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

module Core
  module Filtering
    class ProcessingStage
      PRE = 'pre-processing'
      POST = 'post-processing'

      ALL = [
        PRE,
        POST
      ]
    end
  end
end
