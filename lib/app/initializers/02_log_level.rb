# frozen_string_literal: true
#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'stubs/app_config'
require 'app/config'
require 'utility/logger'

logger = AppConfig.connectors_logger
logger.level = App::Config[:log_level] || 'info'

Utility::Logger.setup!(logger)
