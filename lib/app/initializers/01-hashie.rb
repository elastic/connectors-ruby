# frozen_string_literal: true
#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# Suppress all warnings from Hashie::Mash settings keys over methods
Hashie::Mash.instance_variable_set(:@disable_warnings, true)
