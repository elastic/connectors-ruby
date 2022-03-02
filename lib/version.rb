#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
require 'English'

VERSION = '0.0.1'

# The Git revision is picked by tryin these operations in order:
# - run `git rev-parse HEAD` directly
# - grabbed the stored `lib/.revision` generated with `make build` if present
# - fallback to `Unknown`
revision = `git rev-parse HEAD`
if $CHILD_STATUS.success?
  REVISION = revision
else
  # use the .revision file if present
  stored_revision = File.join(__dir__, '.revision')
  REVISION = if File.exist?(stored_revision)
               File.read(stored_revision)
             else
               'Unknown'
             end
end
