#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'utility'

def required_path(absolute_path)
  absolute_dir = File.dirname(absolute_path)
  relative_dir = absolute_dir.sub(/.*lib\/connectors/, 'connectors')
  name = File.basename(absolute_path, '.rb')
  File.join(relative_dir, name)
end

Dir[File.join(__dir__, 'connectors/**/*.rb')].each { |f| require required_path(f) }
