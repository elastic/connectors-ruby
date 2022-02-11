#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'logger'
require 'java'

java_package 'co.elastic.connectors.stubs'
class AppConfig
  def self.connectors_logger
    Logger.new(STDOUT)
  end
end
