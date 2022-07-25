#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Utility
  # taken from https://regex101.com/r/cU7zG2/1
  CRON_REGEXP = /^\s*($|#|\w+\s*=|(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?(?:,(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?)*)\s+(\?|\*|(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?(?:,(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?)*)\s+(\?|\*|(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?(?:,(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?)*|\?|\*|(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?(?:,(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?)*)\s+(\?|\*|(?:[0-6])(?:(?:-|\/|,|#)(?:[0-6]))?(?:L)?(?:,(?:[0-6])(?:(?:-|\/|,|#)(?:[0-6]))?(?:L)?)*|\?|\*|(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?(?:,(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?)*)(|\s)+(\?|\*|(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?(?:,(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?)*))$/

  # see https://github.com/quartz-scheduler/quartz/blob/master/quartz-core/src/main/java/org/quartz/CronExpression.java
  module Cron
    def self.convert_expression_from_quartz_to_unix(expression)
      @seconds = '*'
      @minutes = '*'
      @hours = '*'
      @day_of_month = '*'
      @month = '*'
      @day_of_week = '*'
      @year = '*'

      expression.match(CRON_REGEXP) { |m|
        @seconds = m[2]
        @minutes = m[3]
        @hours = m[4]
        @day_of_month = m[5]
        @month = m[6]
        @day_of_week = m[7]
        @year = m[9]
      }

      # ? for day of week means - "any day of week that matches other part of regex" if, for example particular day of month is provided.
      # We don't actually support it :/
      @day_of_week = '*' if @day_of_week == '?'

      # Unix cron has five: minute, hour, day, month, and dayofweek
      # Quartz adds seconds and year
      converted_expression = "#{@minutes} #{@hours} #{@day_of_month} #{@month} #{@day_of_week}"

      Utility::Logger.debug("Converted Quartz Cron expression \"#{expression}\" to Standard Cron Expression \"#{converted_expression}\"")

      converted_expression
    end
  end
end
