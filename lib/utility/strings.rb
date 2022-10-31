#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Utility
  class Strings
    class << self
      def format_string_array(elements = [], default: ' ', delimiter: '\'', separator: ', ')
        return default if elements.nil? || elements.empty?

        separated_elements = elements.join("#{delimiter}#{separator}#{delimiter}")

        "#{delimiter}#{separated_elements}#{delimiter}"
      end
    end
  end
end
