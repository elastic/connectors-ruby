#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'logger'
require 'utility/logger'
require 'active_support/core_ext/module'

module Utility
  module Environment
    def self.set_execution_environment(config, &block)
      # Set UTC as the timezone
      ENV['TZ'] = 'UTC'
      Logger.level = config[:log_level]
      es_config = config[:elasticsearch]
      disable_warnings = if es_config.has_key?(:disable_warnings)
                           es_config[:disable_warnings]
                         else
                           true
                         end

      #if disable_warnings
      #  Logger.info('Disabling warnings')
      #  Kernel.silence_warnings(&block)
      #else
      #  Logger.info('Enabling warnings')
      #  Kernel.enable_warnings(&block)
      #end
      block.call
    end
  end
end
