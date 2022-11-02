#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Utility
  class Common
    class << self
      def return_if_present(*args)
        args.each do |arg|
          return arg unless arg.nil?
        end
        nil
      end
    end
  end
end
