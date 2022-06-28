require 'remedy'

module App

  class Menu
    attr_reader :items
    attr_reader :title
    attr_reader :index

    def initialize(title, items)
      super()
      @index = 0
      @title = title
      @items = items.map.with_index { |item, i| MenuItem.new(item[:command], item[:hint], i == 0) }
    end

    def select_item(index)
      @index = index
      @items.each_with_index { |item, i| item.selected = (i == index) }
      display
    end

    def select_command
      display
      interaction = Remedy::Interaction.new
      interaction.loop do |key|
        case key.to_s.to_sym
        when :down
          index = @index + 1
          index = 0 if index >= @items.size
          select_item(index)
        when :up
          index = @index - 1
          index = 0 if index < 0
          select_item(index)
        when :control_m
          return @items[@index].command
        else
          # nothing
        end
      end
    end

    private

    def display
      clear_screen
      puts(title)
      @items.each do |item|
        print(item.selected ? '--> ' : '    ')
        puts("#{item.command} - #{item.hint}")
      end
    end

    def clear_screen
      system('clear') || system('cls')
    end

    def read_char
      STDIN.echo = false
      STDIN.raw!

      input = STDIN.getc
      if input == "\e"
        input << STDIN.read_nonblock(3) rescue nil
        input << STDIN.read_nonblock(2) rescue nil
      end
    ensure
      STDIN.echo = true
      STDIN.cooked!
      return input
    end
  end

  class MenuItem
    attr_reader :command
    attr_reader :hint
    attr_accessor :selected

    def initialize(command, hint, selected = false)
      super()
      @command = command
      @hint = hint
      @selected = selected
    end
  end
end
