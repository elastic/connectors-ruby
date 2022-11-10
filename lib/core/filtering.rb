#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering/post_process_engine'
require 'core/filtering/post_process_result'
require 'core/filtering/simple_rule'

module Core::Filtering
  FILTERING = 'filtering'
  DOMAIN = 'domain'
  ACTIVE = 'active'
  DRAFT = 'draft'
  RULES = 'rules'
  ADVANCED_SNIPPET = 'advanced_snippet'
  DEFAULT_DOMAIN = 'DEFAULT'
  VALIDATION = 'validation'
  WARNINGS = 'warnings'
end
