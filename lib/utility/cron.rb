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

      converted_expression = expression.dup.gsub('?', '*')

      matched = false
      converted_expression.match(CRON_REGEXP) { |m|
        @seconds = [m[2]]
        @minutes = [m[3]]
        @hours = [m[4]]
        @day_of_month = [m[5]]
        @month = [m[6]]
        @day_of_week = [m[7]]
        @year = [m[9]]
        matched = true
      }

      raise StandardError.new('Unknown format {expression}') unless matched

      # Unix cron has five: minute, hour, day, month, and day of week
      # Quartz adds seconds and year
      converted_expression = build_expression(converted_expression)

      Utility::Logger.debug("Converted Quartz Cron expression \"#{expression}\" to Standard Cron Expression \"#{converted_expression}\"")

      converted_expression
    end

    def self.build_expression(expression)
      @seconds ||= []
      @minutes ||= []
      @hours ||= []
      @day_of_month ||= []
      @month ||= []
      @day_of_week ||= []
      @year ||= []

      expr_on = SECOND
      expressions = expression.strip.upcase.split(/\t|\s+/)
      expressions.each do |expr|
        if expr_on > YEAR
          break # we've processed the year field
        end
        # throw an exception if L is used with other days of the month
        if expr_on == DAY_OF_MONTH && expr.include?('L') && expr.length > 1 && expr.include?(',')
          raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the month is not implemented')
        end
        # throw an exception if L is used with other days of the week
        if expr_on == DAY_OF_WEEK && expr.include?('L') && expr.length > 1 && expr.include?(',')
          raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the week is not implemented')
        end
        if expr_on == DAY_OF_WEEK && expr.scan(/#/).length > 1 && expr.include?(',')
          raise StandardError.new('Support for specifying \'L\' and \'LW\' with other days of the week is not implemented')
        end
        expression_vals = expr.split(',')
        expression_vals.each do |expression_val|
          store_expression_vals(0, expression_val, expr_on)
          expr_on += 1
        end
      end
      if expr_on <= DAY_OF_WEEK
        raise StandardError.new("Unexpected end of expression #{expression}: #{expr_on}")
      end
      if expr_on <= YEAR
        store_expression_vals(0, '*', YEAR) # default the year to '*'
      end
      dow = get_set(DAY_OF_WEEK) || []
      dom = get_set(DAY_OF_MONTH) || []

      # Copying the logic from the UnsupportedOperationException below
      # to determine which exception to throw based on the presence
      # of both a day-of-week and a day-of-month value

      day_of_m_spec = !dom.include?(NO_SPEC)
      day_of_w_spec = !dow.include?(NO_SPEC)
      if !day_of_m_spec || day_of_w_spec
        if !day_of_w_spec || day_of_m_spec
          raise StandardError.new('Support for specifying both a day-of-week AND a day-of-month parameter is not implemented.')
        end
      end
      "#{@minutes.first} #{@hours.first} #{@day_of_month.first} #{@month.first} #{@day_of_week.first} #{@year.first}"
    end

    def self.store_expression_vals(pos, s, type)
      incr = 0
      i = skip_white_space(pos, s)
      if i >= s.length
        return i
      end
      c = s[i]
      if (c >= 'A' && c <= 'Z') && (s != 'L' && s != 'LW' && !/^L-\d*W?/.match?(s))
        sub = s[i..i + 3]
        s_val = -1
        e_val = -1
        if type == MONTH
          s_val = get_month_number(sub) + 1
          if s_val <= 0
            raise StandardError.new("Invalid Month value: #{sub}")
          end
          if s.length > i + 3
            c = s[i + 3]
            if c == '-'
              i += 4
              sub = s[i..i + 3]
              e_val = get_month_number(sub) + 1
              if e_val <= 0
                raise StandardError.new("Invalid Month value: #{sub}")
              end
            end
          end
        elsif type == DAY_OF_WEEK
          s_val = get_day_number(sub)
          if s_val < 0
            raise StandardError.new("Invalid Day-of-Week value: #{sub}")
          end
          if s.length > i + 3
            c = s[i + 3]
            if c == '-'
              i += 4
              sub = s[i..i + 3]
              e_val = get_day_number(sub)
              if e_val < 0
                raise StandardError.new("Invalid Day-of-Week value: #{sub}")
              end
            elsif c == '#'
              i += 4
              @nth_day_of_week = s[i..-1].to_i
              if num < 1 || num > 5
                raise StandardError.new("A numeric value between 1 and 5 must follow the '#' option")
              end
            elsif c == 'L'
              @last_day_of_week = true
              i += 1
            end
          end
        else
          raise StandardError.new("Illegal characters for this position: #{sub}")
        end
        if e_val != -1
          incr = 1
        end
        add_to_set(s_val, e_val, incr, type)
        return i + 3
      end
      if c == '?'
        i += 1
        if i + 1 < s.length && s[i] != ' ' && s[i + 1] != "\t"
          raise StandardError.new("Illegal character after '?': #{s[i]}")
        end
        if type != DAY_OF_MONTH && type != DAY_OF_WEEK
          raise StandardError.new("'?' can only be specified for Day-of-Month or Day-of-Week.")
        end
        if type == DAY_OF_WEEK && !@last_day_of_month
          val = @day_of_month.last
          if val == nil || val == NO_SPEC_INT
            raise StandardError.new("'?' can only be specified for Day-of-Month -OR- Day-of-Week.")
          end
        end
        add_to_set(NO_SPEC_INT, -1, 0, type)
        return i
      end

      if c == '*' || c == '/'
        if c == '*' && i + 1 >= s.length
          add_to_set(ALL_SPEC_INT, -1, incr, type)
          return i + 1
        elsif c == '/' && (i + 1 >= s.length || s[i + 1] == ' ' || s[i + 1] == "\t")
          raise StandardError.new("'/' must be followed by an integer.")
        elsif c == '*'
          i += 1
        end
        c = s[i]
        if c == '/' # is an increment specified?
          i += 1
          if i >= s.length
            raise StandardError.new("Unexpected end of string.")
          end
          incr = get_numeric_value(s, i)
          i += 1
          if incr > 10
            i += 1
          end
          check_increment_range(incr, type, i)
        else
          incr = 1
        end
        add_to_set(ALL_SPEC_INT, -1, incr, type)
        return i
      else
        if c == 'L'
          i += 1
          if type == DAY_OF_MONTH
            @last_day_of_month = true
          end
          if type == DAY_OF_WEEK
            add_to_set(7, 7, 0, type)
          end
          if type == DAY_OF_MONTH && s.length > i
            c = s[i]
            if c == '-'
              vs = get_value(0, s, i + 1)
              @last_day_offset = vs.value
              if @last_day_offset > 30
                raise StandardError.new("Offset from last day must be <= 30")
              end
              i = vs.pos
            end
            if s.length > i
              c = s[i]
              if c == 'W'
                @nearest_weekday = true
                i += 1
              end
            end
          end
          return i
        else
          if c >= '0' && c <= '9'
            val = c.to_i
            i += 1
            if i >= s.length
              add_to_set(val, -1, -1, type)
            else
              c = s[i]
              if c >= '0' && c <= '9'
                vs = get_value(val, s, i)
                val = vs.value
                i = vs.pos
              end
              i = check_next(i, s, val, type)
              return i
            end
          else
            throw StandardError.new("Unexpected character: #{c}")
          end
        end
      end
      return i
    end

    def self.check_increment_range(incr, type, idx_pos)
      if incr > 59 && (type == MINUTE || type == SECOND)
        raise StandardError.new("Increment > 60 : #{incr} #{type} #{idx_pos}")
      else
        if incr > 23 && type == HOUR
          raise StandardError.new("Increment > 24 : #{incr} #{type} #{idx_pos}")
        else
          if incr > 31 && type == DAY_OF_MONTH
            raise StandardError.new("Increment > 31 : #{incr} #{type} #{idx_pos}")
          else
            if incr > 7 && type == DAY_OF_WEEK
              raise StandardError.new("Increment > 7 : #{incr} #{type} #{idx_pos}")
            else
              if incr > 12 && type == MONTH
                raise StandardError.new("Increment > 12 : #{incr} #{type} #{idx_pos}")
              else
                if incr > MAX_YEAR && type == YEAR
                  raise StandardError.new("Increment > #{MAX_YEAR} : #{incr} #{type} #{idx_pos}")
                end
              end
            end
          end
        end
      end
    end

    def self.check_next(pos, s, val, type)
      end_index = -1
      i = pos
      if i >= s.length
        add_to_set(val, end_index, -1, type)
        return i
      end
      c = s[pos]
      if c == 'L'
        if type == DAY_OF_WEEK
          if val < 1 || val > 7
            raise StandardError.new('Day-of-Week values must be between 1 and 7')
          end
          @last_day_of_week = true
        else
          raise StandardError.new("'L' option is not valid here. (pos=#{pos})")
        end
        set = get_set(type)
        set << val
        i += 1
        return i
      end
      if c == 'W'
        if type == DAY_OF_MONTH
          @nearest_weekday = true
        else
          raise StandardError.new("'W' option is not valid here. (pos=#{pos})")
        end
        if val > 31
          raise StandardError.new("The 'W' option does not make sense with values larger than 31 (max number of days in a month)")
        end
        set = get_set(type)
        set << val
        i += 1
        return i
      end

      if c == '#'
        if type != DAY_OF_WEEK
          raise StandardError.new("'#' option is not valid here. (pos=#{pos})")
        end
        i += 1
        @nth_day_of_week = s[i..-1].to_i
        if @nth_day_of_week < 1 || @nth_day_of_week > 5
          raise StandardError.new('A numeric value between 1 and 5 must follow the # option')
        end
        set = get_set(type)
        set << val
        i += 1
        return i
      end

      if c == '-'
        i += 1
        c = s[i]
        v = c.to_i
        end_index = v
        i += 1
        if i < s.length
          add_to_set(val, end_index, 1, type)
          return i
        end
        c = s[i]
        if c >= '0' && c <= '9'
          vs = get_value(v, s, i)
          end_index = vs.value
          i = vs.pos
        end
        if i < s.length && s[i] == '/'
          i += 1
          c = s[i]
          v2 = c.to_i
          i += 1
          if i >= s.length
            add_to_set(val, end_index, v2, type)
            return i
          end
          c = s[i]
          if c >= '0' && c <= '9'
            vs = get_value(v2, s, i)
            i = vs.pos
            return i
          else
            add_to_set(val, end_index, v2, type)
            return i
          end
        else
          add_to_set(val, end_index, 1, type)
          return i
        end
      end

      if c == '/'
        if i + 1 >= s.length || s[i + 1] == ' ' || s[i + 1] == "\t"
          raise StandardError.new("'/' must be followed by an integer.")
        end
        i += 1
        c = s[i]
        v2 = c.to_i
        i += 1
        if i >= s.length
          check_increment_range(v2, type, i)
          add_to_set(val, end_index, v2, type)
          return i
        end
        c = s[i]
        if c >= '0' && c <= '9'
          vs = get_value(v2, s, i)
          v3 = vs.value
          check_increment_range(v3, type, i)
          add_to_set(val, end_index, v3, type)
          i = vs.pos
          return i
        else
          raise StandardError.new("'/' must be followed by an integer.")
        end
      end
      add_to_set(val, end_index, 0, type)
      i += 1
      return i
    end

    def self.get_expression_summary
      pairs = []
      pairs << ['seconds: ', @seconds]
      pairs << ['minutes: ', @minutes]
      pairs << ['hours: ', @hours]
      pairs << ['day_of_month: ', @day_of_month]
      pairs << ['month: ', @month]
      pairs << ['day_of_week: ', @day_of_week]
      pairs << ['last_day_of_week: ', @last_day_of_week]
      pairs << ['nearest_weekday: ', @nearest_weekday]
      pairs << ['nth_day_of_week: ', @nth_day_of_week]
      pairs << ['last_day_of_month: ', @last_day_of_month]
      pairs << ['year', @year]
      pairs.map { |el| "#{el[0]}#{el[1]}" }.join("\n").to_s
    end

    def self.get_expression_set_summary(list)
      if list.include?(NO_SPEC)
        return '?'
      end
      if list.include?(ALL_SPEC)
        return '*'
      end
      list.sort.join(',')
    end

    def self.add_to_set(val, end_index, incr, type)
      set = get_set(type)
      if type == SECOND || type == MINUTE
        if (val < 0 || val > 59) && val != ALL_SPEC_INT
          raise StandardError.new('Minute and Second values must be between 0 and 59')
        end
      else
        if type == HOUR
          if (val < 0 || val > 23) && val != ALL_SPEC_INT
            raise StandardError.new('Hour values must be between 0 and 23')
          end
        else
          if type == DAY_OF_MONTH
            if (val < 1 || val > 31) && val != ALL_SPEC_INT && val != NO_SPEC_INT
              raise StandardError.new('Day of month values must be between 1 and 31')
            end
          else
            if type == MONTH
              if (val < 1 || val > 12) && val != ALL_SPEC_INT
                raise StandardError.new('Month values must be between 1 and 12')
              end
            else
              if type == DAY_OF_WEEK
                if (val < 1 || val > 7) && val != ALL_SPEC_INT && val != NO_SPEC_INT
                  raise StandardError.new('Day-of-Week values must be between 1 and 7')
                end
              else
                if type == YEAR
                  if (val < 1970 || val > MAX_YEAR) && val != ALL_SPEC_INT
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
          set << val
        else
          set << NO_SPEC
        end
        return
      end
      start_at = val
      stop_at = end_index
      if val == ALL_SPEC_INT && incr <= 0
        incr = 1
        set << ALL_SPEC
      end
      if type == SECOND || type == MINUTE
        # if stop_at == 60 && incr == 1
        #   stop_at = 0
        #   set << ALL_SPEC
        # end
        if stop_at == -1
          stop_at = 59
        end
        if start_at == -1 || start_at == ALL_SPEC_INT
          start_at = 0
        end
      else
        if type == HOUR
          # if stop_at == 24 && incr == 1
          #   stop_at = 0
          #   set << ALL_SPEC
          # end
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
            # if stop_at == 32 && incr == 1
            #   stop_at = 1
            #   set << ALL_SPEC
            # end
          else
            if type == MONTH
              if stop_at == -1
                stop_at = 12
              end
              if start_at == -1 || start_at == ALL_SPEC_INT
                start_at = 1
              end
              # if stop_at == 13 && incr == 1
              #   stop_at = 1
              #   set << ALL_SPEC
              # end
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
                  set << ALL_SPEC
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
                    set << ALL_SPEC
                  end
                end
              end
            end
          end
        end
      end
      max = -1
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
          set << i
        else
          i2 = i % max
          if i2 == 0 && (type == DAY_OF_WEEK || type == MONTH || type == DAY_OF_MONTH)
            i2 = max
          end
          set << i2
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
      s1 = v.dup.to_s
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
