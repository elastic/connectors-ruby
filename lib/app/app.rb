#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/worker'
require 'app/config'
require 'app/preflight_check'
require 'utility/environment'
require 'utility/logger'

module App
  Utility::Environment.set_execution_environment(App::Config) do
    App::PreflightCheck.run!
    worker = App::Worker.new(
      connector_id: App::Config['connector_id'],
      service_type: App::Config['service_type']
    )
    worker.start!
  rescue App::PreflightCheck::CheckFailure => e
    Utility::Logger.error("Preflight check failed: #{e.message}")
    exit(-1)
  end
end
