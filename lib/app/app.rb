#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

$LOAD_PATH << '../'

require 'app/worker'
require 'app/config'
require 'utility/logger'

module App
  Utility::with_logging(App::Config) do
    App::Worker.start!
  end
end
