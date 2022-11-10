#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Utility
  class Filtering
    class << self
      def extract_filter(filtering)
        return {} unless filtering.present?

        # assume for now, that first object in filtering array or a filter object itself is the only filtering object
        filter = filtering.is_a?(Array) ? filtering.first : filtering

        filter.present? ? filter : {}
      end
    end
  end
end
