#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Utility
  # taken from https://regex101.com/r/cU7zG2/1
  # previous regexp allowed days of the week as [0-6], but it's not correct because the Kibana scheduler
  # is using [1-7] for days of the week, aligned with the Quartz scheduler: see http://www.quartz-scheduler.org/documentation/2.4.0-SNAPSHOT/tutorials/tutorial-lesson-06.html
  # But just replacing with [1-7] would also be incorrect, since according to the Cron spec, the days of the week
  # are 1-6 for Monday-Saturday, and 0 or 7 for Sunday, 7 being a non-standard but still widely used. So, we need to
  # allow for 0-7.
  CRON_REGEXP = /^\s*($|#|\w+\s*=|(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?(?:,(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?)*)\s+(\?|\*|(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?(?:,(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?)*)\s+(\?|\*|(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?(?:,(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?)*|\?|\*|(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?(?:,(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?)*)\s+(\?|\*|(?:[0-7])(?:(?:-|\/|,|#)(?:[0-7]))?(?:L)?(?:,(?:[0-7])(?:(?:-|\/|,|#)(?:[0-7]))?(?:L)?)*|\?|\*|(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?(?:,(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?)*)(|\s)+(\?|\*|(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?(?:,(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?)*))$/

  # see https://github.com/quartz-scheduler/quartz/blob/master/quartz-core/src/main/java/org/quartz/CronExpression.java
  module Cron
    def self.check(expr)
      raise StandardError.new("Unsupported expression #{expr} with #") if expr.include?('#')
      raise StandardError.new("Unsupported expression #{expr} with L") if expr.include?('L')
      raise StandardError.new("Unsupported expression #{expr} with W") if expr.include?('W') && !expr.include?('WED')

      expr
    end

    def self.quartz_to_crontab(expression)
      @seconds = '*'
      @minutes = '*'
      @hours = '*'
      @day_of_month = '*'
      @month = '*'
      @day_of_week = '*'
      @year = '*'

      # ? is not supported
      converted_expression = expression.tr('?', '*')

      matched = false
      converted_expression.match(CRON_REGEXP) { |m|
        @seconds = m[2]
        @minutes = m[3]
        @hours = m[4]
        @day_of_month = check(m[5])
        @month = check(m[6])
        @day_of_week = scheduler_dow_to_crontab(check(m[7])).to_s
        @year = m[9]
        matched = true
      }

      raise StandardError.new("Unknown format #{expression}") unless matched

      # Unix cron has five: minute, hour, day, month, and dayofweek
      # Quartz adds seconds and year
      converted_expression = "#{@minutes} #{@hours} #{@day_of_month} #{@month} #{@day_of_week}"

      Utility::Logger.debug("Converted Quartz Cron expression '#{expression}' to Standard Cron Expression '#{converted_expression}'")

      converted_expression
    end

    # As described above, Quartz uses 1-7 for days of the week, starting with Sunday,
    # while Unix cron uses 0-6, starting with Monday, and also 7 as an extra non-standard index for Sunday.
    # (see https://en.wikipedia.org/wiki/Cron for more details)
    # This means that we need to shift the Quartz day of week that are between 1 and 7 by minus one, but we also allow 0
    # in case it's not a quartz expression but already the cron standard.
    def self.scheduler_dow_to_crontab(day)
      unless /\d/.match?(day)
        return day
      end
      if day.to_i <= 0
        return day
      end
      day.to_i - 1
    end
  end
end
