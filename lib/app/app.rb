#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/dispatcher'
require 'app/config'
require 'app/preflight_check'
require 'utility/environment'
require 'utility/logger'
require 'core'

module App
  Utility::Environment.set_execution_environment(App::Config) do
    job = Core::ConnectorJob.fetch_by_id('bjHfXYQBO_lgw7YQr9eu')
    Utility::Logger.info("job id = #{job.id}, job status = #{job.status}")
    job.reload
    Utility::Logger.info("job id = #{job.id}, job status = #{job.status}")
    #App::PreflightCheck.run!
    #App::Dispatcher.start!
  rescue App::PreflightCheck::CheckFailure => e
    Utility::Logger.error("Preflight check failed: #{e.message}")
    exit(-1)
  end
end
