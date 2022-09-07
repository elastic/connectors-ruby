#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/logger'

module Utility
  # taken from https:#regex101.com/r/cU7zG2/1
  CRON_REGEXP = /^\s*($|#|\w+\s*=|(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?(?:,(?:[0-5]?\d)(?:(?:-|\/|,)(?:[0-5]?\d))?)*)\s+(\?|\*|(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?(?:,(?:[01]?\d|2[0-3])(?:(?:-|\/|,)(?:[01]?\d|2[0-3]))?)*)\s+(\?|\*|(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?(?:,(?:0?[1-9]|[12]\d|3[01])(?:(?:-|\/|,)(?:0?[1-9]|[12]\d|3[01]))?)*)\s+(\?|\*|(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?(?:,(?:[1-9]|1[012])(?:(?:-|\/|,)(?:[1-9]|1[012]))?(?:L|W)?)*|\?|\*|(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?(?:,(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(?:(?:-)(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC))?)*)\s+(\?|\*|(?:[0-6])(?:(?:-|\/|,|#)(?:[0-6]))?(?:L)?(?:,(?:[0-6])(?:(?:-|\/|,|#)(?:[0-6]))?(?:L)?)*|\?|\*|(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?(?:,(?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:(?:-)(?:MON|TUE|WED|THU|FRI|SAT|SUN))?)*)(|\s)+(\?|\*|(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?(?:,(?:|\d{4})(?:(?:-|\/|,)(?:|\d{4}))?)*))$/

  SECOND = 0
  MINUTE = 1
  HOUR = 2
  DAY_OF_MONTH = 3
  MONTH = 4
  DAY_OF_WEEK = 5
  YEAR = 6
  ALL_SPEC_INT = 99 # '*'
  NO_SPEC_INT = 98 # '?'
  Integer ALL_SPEC = ALL_SPEC_INT
  Integer NO_SPEC = NO_SPEC_INT

  # see https:#github.com/quartz-scheduler/quartz/blob/master/quartz-core/src/main/java/org/quartz/CronExpression.java
  module Cron
    @month_map = {
      'JAN' => 0,
      'FEB' => 1,
      'MAR' => 2,
      'APR' => 3,
      'MAY' => 4,
      'JUN' => 5,
      'JUL' => 6,
      'AUG' => 7,
      'SEP' => 8,
      'OCT' => 9,
      'NOV' => 10,
      'DEC' => 11
    }
    @day_map = {
      'SUN' => 1,
      'MON' => 2,
      'TUE' => 3,
      'WED' => 4,
      'THU' => 5,
      'FRI' => 6,
      'SAT' => 7
    }

    MAX_YEAR = DateTime.now.year + 100

    def self.check(expr)
      raise StandardError.new("Unsupported expression #{expr} with #") if expr.include?('#')
      raise StandardError.new("Unsupported expression #{expr} with L") if expr.include?('L')
      raise StandardError.new("Unsupported expression #{expr} with W") if expr.include?('W') && !expr.include?('WED')

      expr
    end

    def self.quartz_to_crontab(expression)
      # ? is not supported
      converted_expression = expression.tr('?', '*')
      build_expression(converted_expression)

      check(@day_of_week)
      check(@day_of_month)

      # Unix cron has five: minute, hour, day, month, and day of week
      # Quartz adds seconds and year
      converted_expression = "#{@minutes} #{@hours} #{@day_of_month} #{@month} #{@day_of_week}"
      Utility::Logger.debug("Converted Quartz Cron expression '#{expression}' to Standard Cron Expression '#{converted_expression}'")
      converted_expression
    end

    def self.build_expression(expression)
      parse_cron(expression)
    end

    # Parses a cron expression into local variables
    def self.parse_cron(expression)
      items = expression.split(/\t|\s+/)
      if items.length < 5 || items.length > 7
        raise StandardError.new('Invalid cron expression {expression}')
      end
      @seconds, @minutes, @hours, @day_of_month, @month, @day_of_week, @year = items
      @possible_seconds = [0] # ignore
      @possible_minutes = MinuteParser.parse(@minutes)
      @possible_hours = HourParser.parse(@hours)
      @possible_day_of_month = MonthDayParser.parse(@day_of_month)
      @possible_month = MonthParser.parse(@month)
      @possible_day_of_week = WeekDayParser.parse(@day_of_week)
      if @year.nil?
        @year = '*'
      end
      @possible_year = YearParser.parse(@year)
    end

    #   Abstract class to create parsers for parts of quartz expressions
    # Each parser can be used per token and a specific parser needs to provide
    #  the valid ranges of the quartz part and a dict of REPLACEMENTS in upper case
    # See the specific parsers below (Ex: MinuteParser, WeekDayParser, etc..)
    # All values:
    #     A star can be used to specify all valid values
    # Multiple options:
    #     Each of the expression parsed can contain a list of expressions as
    #      a comma separated list. duplicates are removed
    #     Example: 0,1,4 Means 0, 1 and 4
    # Ranges:
    #     A dash can be used to represent ranges
    #     2-5 Means 2 to 3
    # Step:
    #     A slash can be used to specify a step
    #     Example: */2 Means to pick one of every two values.
    #              if the valid range is 0 to 3 it will return 0 and 2
    # Replacements:
    #     Each specific parser can define String replacements for the expression.
    #     Ex: JAN is ok for 1 (Jan) [ Case insensitive ]
    # Other examples:
    #     "1,3-6,8" -> [1, 3, 4, 5, 6, 8].
    #     '1-3, 0-10/2" -> [0, 1, 2, 3, 4, 6, 8, 10]
    class Parser

      MIN_VALUE = nil # Min value the expression can have
      MAX_VALUE = nil # Max value inclusive the expression can have
      REPLACEMENTS = {} # String replacements for the expression.

      QUARTZ_REGEXP = /(?<start>(\d+)|\*)(-(?<end>\d+))?(\/(?<step>\d+))?/

      # Parses the quartz expression
      #     :param expression: expression string encoded to parse
      #     returns: sorted list of unique elements resulting from the expression
      def self.parse(expression)
        groups = expression.split(",").map { |item| parse_item(item) }
        groups.flatten.uniq.sort
      end

      # Parses one of the comma separated expressions within the full quartz expression
      def self.parse_item(expression)
        expression = expression.upcase
        self::REPLACEMENTS.each { |k, v| expression = expression.sub(k.to_s, v) }
        matches = self::QUARTZ_REGEXP.match(expression)
        if matches.nil?
          raise "Invalid expression: #{expression}"
        end
        start_el = matches.named_captures['start']
        step = matches.named_captures['step'] || 1
        not_stepping = matches.named_captures['step'].nil?
        end_el = matches.named_captures['end']
        if end_el.nil?
          end_el = not_stepping ? start_el : self::MAX_VALUE
        end

        if start_el == "*"
          start_el = self::MIN_VALUE
          end_el = self::MAX_VALUE
        end
        values = (start_el.to_i..end_el.to_i).step(step.to_i).to_a
        values.each do |v|
          if v < self::MIN_VALUE || v > self::MAX_VALUE
            raise "Invalid expression: #{expression}"
          end
        end
        values
      end
    end

    # Custom parser for minutes
    class MinuteParser < Parser

      MIN_VALUE = 0
      MAX_VALUE = 59
    end

    # Custom parser for hours
    class HourParser < Parser
      MIN_VALUE = 0
      MAX_VALUE = 23
    end

    # Custom parser for month days
    class MonthDayParser < Parser

      MIN_VALUE = 1
      MAX_VALUE = 31
    end

    # Custom parser for months
    class MonthParser < Parser
      MIN_VALUE = 1
      MAX_VALUE = 12
      REPLACEMENTS = {
        "JAN": "1",
        "FEB": "2",
        "MAR": "3",
        "APR": "4",
        "MAY": "5",
        "JUN": "6",
        "JUL": "7",
        "AUG": "8",
        "SEP": "9",
        "OCT": "10",
        "NOV": "11",
        "DEC": "12"
      }
    end

    # Custom parser for week days
    class WeekDayParser < Parser

      MIN_VALUE = 1
      MAX_VALUE = 7
      REPLACEMENTS = {
        "MON": "1",
        "TUE": "2",
        "WED": "3",
        "THU": "4",
        "FRI": "5",
        "SAT": "6",
        "SUN": "7"
      }
    end

    class YearParser < Parser

      MIN_VALUE = 1970
      MAX_VALUE = DateTime.now.year + 100
    end
  end
end
