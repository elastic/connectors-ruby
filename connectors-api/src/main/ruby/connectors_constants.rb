#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'java'

java_package 'co.elastic.connectors.api'
class ConnectorsConstants
  THUMBNAIL_FIELDS = %w[_thumbnail_80x100 _thumbnail_310x430]
  SUBEXTRACTOR_RESERVED_FIELDS = %w[_subextracted_as_of _subextracted_version]
  ALLOW_FIELD = '_allow_permissions'
  DENY_FIELD = '_deny_permissions'
end
