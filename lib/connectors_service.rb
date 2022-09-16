#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'app/config'
require 'app/dispatcher'
require 'app/preflight_check'
require 'utility'

class ConnectorsService
  def self.run!
    Utility::Environment.set_execution_environment(App::Config) do
      App::PreflightCheck.run!
      App::Dispatcher.start!
    rescue App::PreflightCheck::CheckFailure => e
      Utility::Logger.error("Preflight check failed: #{e.message}")
      exit(-1)
    end
  end
end
