#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'stubs/app_config'

module Connectors
  class << self
    def config
      AppConfig.connectors
    end
  end
end
