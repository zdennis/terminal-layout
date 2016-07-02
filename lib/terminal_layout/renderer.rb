require 'terminfo'
require 'termios'
require 'highline/system_extensions'

module TerminalLayout
  class Renderer
    include HighLine::SystemExtensions
    include EventEmitter

    attr_reader :term_info

    def initialize(output: $stdout)
      @output = output
      @term_info = TermInfo.new ENV["TERM"], @output
      @previously_printed_lines = []
      @x, @y = 0, 0
    end

    def render_cursor(input_box)
      Treefell['render'].puts %|\nCURSOR RENDER: #{self.class}##{__callee__} caller=#{caller[0..5].join("\n")}}|
      move_up_n_rows @y
      move_to_beginning_of_row

      position = input_box.position

      cursor_position = input_box.cursor_position
      cursor_x = cursor_position.x
      cursor_y = cursor_position.y

      relative_position_on_row = position
      initial_offset_x = input_box.computed[:x] + (input_box.computed[:y] * terminal_width)
      cursor_x = 0
      cursor_y = 0

      absolute_position_on_row = relative_position_on_row + initial_offset_x
      loop do
        if absolute_position_on_row >= terminal_width
          # reset offset
          initial_offset_x = 0

          absolute_position_on_row -= terminal_width

          # move down a line
          cursor_y += 1
        else
          # we fit on the current line
          cursor_x = absolute_position_on_row
          break
        end
      end

      if @y < cursor_y
        # moving backwards
        move_up_n_rows(@y - cursor_y)
      elsif @y > cursor_y
        # moving forwards
        move_down_n_rows(cursor_y - @y)
      end

      move_down_n_rows cursor_y
      move_to_beginning_of_row
      move_right_n_characters cursor_x

      @x = cursor_x
      @y = cursor_y

      if input_box.style[:cursor] == 'none'
        @output.print @term_info.control_string "civis"
      else
        @output.print @term_info.control_string "cnorm"
      end
    end

    def render(object, reset: false)
      dumb_render(object, reset: reset)
    end

    def find_top_of_tree(object)
      loop do
        break unless object.parent
        object = object.parent
      end
      object
    end

    def fullzip(a, b, &blk)
      results = if a.length >= b.length
        a.zip(b)
      else
        b.zip(a).map(&:reverse)
      end
      if block_given?
        results.each { |*args| blk.call(*args) }
      else
        results
      end
    end

    def dumb_render(object, reset: false)
      Treefell['render'].puts %|\nDUMB RENDER: #{self.class}##{__callee__} reset=#{reset} caller=#{caller[0..5].join("\n")}}|
      if reset
        @y = 0
        @previously_printed_lines.clear
      else
        move_up_n_rows @y
        move_to_beginning_of_row
        @y = 0
      end
      @output.print @term_info.control_string "civis"

      object = find_top_of_tree(object)

      object_width = object.width

      rendered_content = object.render
      printable_content = rendered_content.sub(/\s*\Z/m, '')
      printable_lines = printable_content.split(/\n/).each_with_object([]) do |line, results|
        if line.empty?
          results << line
        else
          results.concat line.scan(/.{1,#{terminal_width}}/)
        end
      end

      i = 0
      fullzip(printable_lines, @previously_printed_lines) do |new_line, previous_line|
        i += 1
        if new_line && new_line != previous_line
          # be sure to reset the terminal at the outset of every line
          # because we don't know what state the previous line ended in
          line2print = "#{new_line}\e[0m"
          term_info.control "el"
          move_to_beginning_of_row
          term_info.control "el"
          @output.puts line2print
          move_to_beginning_of_row
        elsif i <= printable_lines.length
          move_down_n_rows 1
        end
      end

      move_to_beginning_of_row
      clear_screen_down

      # calculate lines drawn so we know where we are
      lines_drawn = (printable_content.length / object_width.to_f).ceil
      @y = lines_drawn

      input_box = object.box.find_child_of_type(InputBox) do |box|
        box.focused?
      end
      render_cursor(input_box)

      @previously_printed_lines = printable_lines
    end

    def clear_to_beginning_of_line ; term_info.control "el1" ; end
    def clear_screen ; term_info.control "clear" ; end
    def clear_screen_down ; term_info.control "ed" ; end
    def move_to_beginning_of_row ; move_to_column 0 ; end
    def move_left ; move_left_n_characters 1 ; end
    def move_left_n_characters(n) ; n.times { term_info.control "cub1" } ; end
    def move_right_n_characters(n) ; n.times { term_info.control "cuf1" } ; end
    def move_to_column_and_row(column, row) ; term_info.control "cup", column, row ; end
    def move_to_column(n) ; term_info.control "hpa", n ; end
    def move_up_n_rows(n) ; n.times { term_info.control "cuu1" } ; end
    def move_down_n_rows(n) ; n.times { term_info.control "cud1" } ; end

    def terminal_width
      terminal_size[0]
    end

    def terminal_height
      terminal_size[1]
    end
  end

end
