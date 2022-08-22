#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/worker'
require 'app/config'
require 'app/dispatcher'
require 'utility/environment'
require 'utility/logger'

module App
  Utility::Environment.set_execution_environment(App::Config) do
    mode = App::Config['mode']
    Utility::Logger.info("Starting as a *** #{mode} ***")
    if mode == 'worker'
      worker = App::Worker.new(
        connector_id: App::Config['connector_id'],
        service_type: App::Config['service_type'],
        is_native: false
      )
      worker.start!
    else
      App::Dispatcher.new.start!
    end
  end
end
