#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/inflector'

module Connectors
  module Stats
    def self.measure(_key, _value = nil, &block)
      block.call
    end

    def self.increment(key, value = 1)
      # no op
    end

    def self.prefix_key(key)
      "connectors.#{key}"
    end

    def self.class_key(klass, deconstantize = true)
      name = klass.name
      # Changes Connectors::GoogleDrive::Adapter to Connectors::GoogleDrive
      name = ActiveSupport::Inflector.deconstantize(name) if deconstantize
      # Changes Connectors::GoogleDrive to GoogleDrive
      name = ActiveSupport::Inflector.demodulize(name)
      # Changes GoogleDrive to google_drive
      ActiveSupport::Inflector.underscore(name)
    end
  end
end
