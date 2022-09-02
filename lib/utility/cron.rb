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
      raise StandardError.new('Unsupported expression {expr}') if expr.include?('#')
      raise StandardError.new('Unsupported expression {expr}') if expr.include?('L')
      raise StandardError.new('Unsupported expression {expr}') if expr.include?('W') && !expr.include?('WED')

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
        @day_of_week = check(m[7])
        @year = m[9]
        matched = true
      }

      raise StandardError.new('Unknown format {expression}') unless matched

      # Unix cron has five: minute, hour, day, month, and dayofweek
      # Quartz adds seconds and year
      converted_expression = "#{@minutes} #{@hours} #{@day_of_month} #{@month} #{@day_of_week}"

      Utility::Logger.debug("Converted Quartz Cron expression \"#{expression}\" to Standard Cron Expression \"#{converted_expression}\"")

      converted_expression
    end

    def self.build_expression(expression)
      expression_parsed = true
      begin
        @seconds ||= []
        @minutes ||= []
        @hours ||= []
        @day_of_month ||= []
        @month ||= []
        @day_of_week ||= []
        @year ||= []

        expr_on = SECOND
        expressions = expression.strip.upcase.split(/\t/)
        expressions.each do |expr|
          if expr_on > YEAR
            break # we've processed the year field
          end
          # throw an exception if L is used with other days of the month
          if expr_on == DAY_OF_MONTH && expr.include?('L') && expr.length > 1 && expr.include?(',')
            raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the month is not implemented')
            expr_on += 1
            next
          end
          # throw an exception if L is used with other days of the week
          if expr_on == DAY_OF_WEEK && expr.include?('L') && expr.length > 1 && expr.include?(',')
            raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the week is not implemented')
            expr_on += 1
            next
          end
          if expr_on == DAY_OF_WEEK && expr.scan(/#/).length > 1 && expr.include?(',')
            raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the week is not implemented')
            expr_on += 1
            next
          end
          expression_vals = expr.split(',')
          expression_vals.each do |expression_val|
            #
          end
        end

      end
    end

    def self.store_expression_vals(expr_on, expression_val)
      incr = 0
      # TODO: implement
    end

    def self.get_expression_set_summary(list)
      if list.include?(NO_SPEC)
        return '?'
      end
      if list.include?(ALL_SPEC)
        return '*'
      end
    end

    def self.add_to_set(val, end_index, incr, type)
      set = get_set(type)
      if type == SECOND || type == MINUTE
        if val < 0 || val > 59
          raise StandardError.new('Minute and Second values must be between 0 and 59')
        end
      else
        if type == HOUR
          if val < 0 || val > 23
            raise StandardError.new('Hour values must be between 0 and 23')
          end
        else
          if type == DAY_OF_MONTH
            if val < 1 || val > 31
              raise StandardError.new('Day of month values must be between 1 and 31')
            end
          else
            if type == MONTH
              if val < 1 || val > 12
                raise StandardError.new('Month values must be between 1 and 12')
              end
            else
              if type == DAY_OF_WEEK
                if val < 1 || val > 7
                  raise StandardError.new('Day-of-Week values must be between 1 and 7')
                end
              else
                if type == YEAR
                  if val < 1970 || val > MAX_YEAR
                    raise StandardError.new("Year values must be between 1970 and #{MAX_YEAR}")
                  end
                end
              end
            end
          end
        end
      end
      if (incr == 0 || incr == -1) && val != ALL_SPEC_INT
        if val != -1
          set += [val]
        else
          set += [NO_SPEC]
        end
        return
      end
      start_at = val
      stop_at = end_index
      if val == ALL_SPEC_INT && incr <= 0
        incr = 1
        set += [ALL_SPEC]
      end
      if type == SECOND || type == MINUTE
        if stop_at == 60 && incr == 1
          stop_at = 0
          set += [ALL_SPEC]
        end
        if stop_at == -1
          stop_at = 59
        end
        if start_at == -1 || start_at == ALL_SPEC_INT
          start_at = 0
        end
      else
        if type == HOUR
          if stop_at == 24 && incr == 1
            stop_at = 0
            set += [ALL_SPEC]
          end
          if stop_at == -1
            stop_at = 23
          end
          if start_at == -1 || start_at == ALL_SPEC_INT
            start_at = 0
          end
        else
          if type == DAY_OF_MONTH
            if stop_at == -1
              stop_at = 31
            end
            if start_at == -1 || start_at == ALL_SPEC_INT
              start_at = 1
            end
            if stop_at == 32 && incr == 1
              stop_at = 1
              set += [ALL_SPEC]
            end
          else
            if type == MONTH
              if stop_at == -1
                stop_at = 12
              end
              if start_at == -1 || start_at == ALL_SPEC_INT
                start_at = 1
              end
              if stop_at == 13 && incr == 1
                stop_at = 1
                set += [ALL_SPEC]
              end
            else
              if type == DAY_OF_WEEK
                if stop_at == -1
                  stop_at = 7
                end
                if start_at == -1 || start_at == ALL_SPEC_INT
                  start_at = 1
                end
                if stop_at == 8 && incr == 1
                  stop_at = 1
                  set += [ALL_SPEC]
                end
              else
                if type == YEAR
                  if stop_at == -1
                    stop_at = MAX_YEAR
                  end
                  if start_at == -1 || start_at == ALL_SPEC_INT
                    start_at = 1970
                  end
                  if stop_at == MAX_YEAR + 1 && incr == 1
                    stop_at = 1970
                    set += [ALL_SPEC]
                  end
                end
              end
            end
          end
        end
      end
      int max = -1
      if stop_at < start_at
        case type
        when SECOND, MINUTE
          max = 60
        when HOUR
          max = 24
        when DAY_OF_MONTH
          max = 31
        when MONTH
          max = 12
        when DAY_OF_WEEK
          max = 7
        when YEAR
          max = MAX_YEAR
        else
          raise 'Start and end values are invalid'
        end
        stop_at += max
      end
      i = start_at
      while i < stop_at
        if max == -1
          set += [i]
        else
          i2 = i % max
          if i2 == 0 && (type == DAY_OF_WEEK || type == MONTH || type == DAY_OF_MONTH)
            i2 = max
          end
          set += [i2]
        end
        i += incr
      end
    end

    def self.get_set(type)
      case type
      when SECOND then @seconds
      when MINUTE then @minutes
      when HOUR then @hours
      when DAY_OF_MONTH then @day_of_month
      when MONTH then @month
      when DAY_OF_WEEK then @day_of_week
      when YEAR then @year
      else nil
      end
    end

    def self.get_value(v, s, i)
      c = s[i]
      s1 = ''
      while c >= '0' && c <= '9'
        s1 += c
        i += 1
        if i >= s.length
          break
        end
        c = s[i]
      end
      ValueSet.new(s1.to_i, i < s.length ? i : i + 1)
    end

    def self.find_next_space(i, s)
      while i < s.length && s[i] != ' ' && s[i] != "\t"
        i += 1
      end
      i
    end

    def self.skip_white_space(i, s)
      while i < s.length && (s[i] == ' ' || s[i] == "\t")
        i += 1
      end
      i
    end

    def self.get_numeric_value(s, i)
      end_of_val = find_next_space(i, s)
      val = s[i..end_of_val]
      val.to_i
    end

    def self.get_month_number(s)
      @month_map[s]
    end

    def self.get_day_number(s)
      @day_map[s]
    end

    class ValueSet
      attr_accessor :value, :pos

      def initialize(value, pos)
        @value = value
        @pos = pos
      end
    end
  end
end
