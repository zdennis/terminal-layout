require 'ansi_string'
require 'ostruct'

module TerminalLayout
  Dimension = Struct.new(:width, :height)
  Position = Struct.new(:x, :y)

  module EventEmitter
    def _callbacks
      @_callbacks ||= Hash.new { |h, k| h[k] = [] }
    end

    def on(type, *args, &blk)
      _callbacks[type] << blk
      self
    end

    def unsubscribe
      _callbacks.clear
    end

    def emit(type, *args)
      _callbacks[type].each do |blk|
        blk.call(*args)
      end
    end
  end

  class RenderObject
    include EventEmitter

    attr_accessor :box, :style, :children, :content, :parent

    def initialize(box, parent:, content:nil, style:{x:nil, y:nil}, renderer:nil)
      @box = box
      @content = ANSIString.new(content)
      @children = []
      @parent = parent
      @renderer = renderer
      @style = style
      style[:x] || style[:x] = 0
      style[:y] || style[:y] = 0

      @box.update_computed(style)
    end

    def offset
      offset_x = self.x
      offset_y = self.y
      _parent = @parent
      loop do
        break unless _parent
        offset_x += _parent.x
        offset_y += _parent.y
        _parent = _parent.parent
      end
      Position.new(offset_x, offset_y)
    end

    def starting_x_for_current_y
      children.map do |child|
        next unless child.float == :left || child.display == :inline
        next unless child.y && child.y <= @current_y && (child.y + child.height - 1) >= @current_y

        [child.x + child.width, x].max
      end.compact.max || 0
    end

    def ending_x_for_current_y
      children.map do |child|
        next unless child.float == :right
        next unless child.y && child.y <= @current_y && (child.y + child.height - 1) >= @current_y

        [child.x, width].min
      end.compact.min || self.width || @box.width
    end

    %w(width height display x y float).each do |method|
      define_method(method){ style[method.to_sym] }

      define_method("#{method}=") do |value|
        style[method.to_sym] = value
        @box.computed[method] = value
      end
    end

    def position
      Position.new(x, y)
    end

    def size
      Dimension.new(width, height)
    end

    def width
      style[:width]
    end

    def height
      style[:height]
    end

    def inspect
      to_s
    end

    def to_str
      to_s
    end

    def to_s
      "<#{self.class.name} position=(#{x},#{y}) dimensions=#{width}x#{height} content=#{content}/>"
    end

    def render
      # Rather than worry about a 2-dimensional space we're going to cheat
      # and convert everything to a single point.
      result = height.times.map { |n| (" " * width) }.join
      result = ANSIString.new(result)

      if content && content.length > 0
        result[0...content.length] = content.dup.to_s
      end

      children.each do |child|
        rendered_content = child.render

        # Find the single point where this child's content should be placed.
        #  (child.y * width): make sure we take into account the row we're on
        #  plus (child.y): make sure take into account the number of newlines
        x = child.x + (child.y * width)
        result[x...(x+rendered_content.length)] = rendered_content
      end

      result
    end

    def layout
      self.children = []
      @current_x = 0
      @current_y = 0
      if @box.display == :block && @box.content.length > 0
        ending_x = ending_x_for_current_y
        available_width = ending_x - @current_x
        new_parent = Box.new(content: nil, style: @box.style.dup.merge(width: available_width))
        inline_box = Box.new(content: @box.content, style: {display: :inline})
        new_parent.children = [inline_box].concat @box.children
        children2crawl = [new_parent]
      else
        children2crawl = @box.children
      end

      children2crawl.each do |cbox|
        if cbox.display == :float
          next if cbox.width.to_i == 0

          render_object = layout_float cbox
          cbox.height = render_object.height

          next if cbox.height.to_i == 0

          self.children << render_object
        elsif cbox.display == :block
          if children.last && children.last.display == :inline && @current_x != 0
            @current_x = 0
            @current_y += 1
          end

          @current_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - @current_x

          if cbox.width && cbox.width > available_width
            @current_y += 1
            @current_x = starting_x_for_current_y
            available_width = ending_x_for_current_y - @current_x
          end

          render_object = render_object_for(cbox, content:nil, style: {width: (cbox.width || available_width)})
          render_object.layout
          render_object.x = @current_x
          render_object.y = @current_y

          if cbox.height
            render_object.height = cbox.height
          end

          next if [nil, 0].include?(render_object.width) || [nil, 0].include?(render_object.height)

          @current_x = 0
          @current_y += [render_object.height, 1].max

          self.children << render_object
        elsif cbox.display == :inline
          @current_x = starting_x_for_current_y if @current_x == 0
          available_width = ending_x_for_current_y - @current_x

          content_i = 0
          content = ""

          loop do
            partial_content = cbox.content[content_i...(content_i + available_width)]
            chars_needed = partial_content.length
            self.children << render_object_for(cbox, content:partial_content, style: {display: :inline, x:@current_x, y: @current_y, width:chars_needed, height:1})

            content_i += chars_needed

            if chars_needed >= available_width
              @current_y += 1
              @current_x = starting_x_for_current_y
              available_width = ending_x_for_current_y - @current_x
            elsif chars_needed == 0
              break
            else
              @current_x += chars_needed
            end

            break if content_i >= cbox.content.length
          end
        end
      end

      if !height
        if children.length >= 2
          last_child = children.max{ |child| child.y }
          self.height = last_child.y + last_child.height
        elsif children.length == 1
          self.height = self.children.first.height
        else
          self.height = @box.height || 0
        end
      end

      self.children
    end

    def layout_float(fbox)
      # only allow the float to be as wide as its parent
      # - first check is the box itself, was it assigned a width?
      if @box.width && fbox.width > width
        fbox.width = width
      end

      if fbox.float == :left
        # if we cannot fit on this line, go to the next
        if @current_x + fbox.width > width
          @current_x = 0
          @current_y += 1
        end

        fbox.x = @current_x
        fbox.y = @current_y

        render_object = render_object_for(fbox, content: fbox.content, style: {height: fbox.height})
        render_object.layout

        @current_x += fbox.width
        return render_object
      elsif fbox.float == :right
        # loop in case there are left floats on the left as we move down rows
        loop do
          starting_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - starting_x

          # if we cannot fit on this line, go to the next
          width_needed = fbox.width
          if width_needed > available_width
            @current_x = 0
            @current_y += 1
          else
            break
          end
        end

        @current_x = ending_x_for_current_y - fbox.width
        fbox.x = @current_x
        fbox.y = @current_y

        render_object = render_object_for(fbox, content: fbox.content, style: {height: fbox.height})
        render_object.layout

        # reset X back to what it should be
        @current_x = starting_x_for_current_y
        return render_object
      end
    end

    def render_object_for(cbox, content:nil, style:{})
      case cbox.display
      when :block
        BlockRenderObject.new(cbox, parent: self, content: content, style: {width:@box.width}.merge(style), renderer:@renderer)
      when :inline
        InlineRenderObject.new(cbox, parent: self, content: content, style: style, renderer:@renderer)
      when :float
        FloatRenderObject.new(cbox, parent: self, content: content, style: {x: @current_x, y: @current_y, float: cbox.float}.merge(style), renderer:@renderer)
      end
    end
  end

  class RenderTree < RenderObject
  end

  class BlockRenderObject < RenderObject
    def initialize(*args)
      super
      style.has_key?(:display) || style[:display] = :block
      style.has_key?(:width) || style[:width] = @box.width
    end
  end

  class FloatRenderObject < BlockRenderObject
  end

  class InlineRenderObject < RenderObject
  end

  class Box
    include EventEmitter

    attr_accessor :style, :children, :content, :computed

    def initialize(style:{}, children:[], content:"")
      @style = style
      @children = children
      @content = ANSIString.new(content)
      @computed = {}

      initialize_defaults

       @children.each do |child|
         child.on(:content_changed) do |*args|
           emit :child_changed
         end

         child.on(:child_changed) do |*args|
           emit :child_changed
         end

         child.on(:cursor_position_changed) do |*args|
           emit :cursor_position_changed
         end
       end
    end

    %w(width height display x y float).each do |method|
      define_method(method){ style[method.to_sym] }
      define_method("#{method}="){ |value| style[method.to_sym] = value }
    end

    def content=(str)
      new_content = ANSIString.new(str)
      if @content != new_content
        old_content = @content
        @content = new_content
        emit :content_changed, old_content, @content
      end
    end

    def children=(new_children)
      old_children = @children
      @children = new_children
      emit :child_changed, old_children, new_children
    end

    def position
      Position.new(x, y)
    end

    def size
      Dimension.new(width, height)
    end

    def width
      style[:width]
    end

    def height
      style[:height]
    end

    def inspect
      to_s
    end

    def to_str
      to_s
    end

    def to_s
      "<Box##{object_id} position=(#{x},#{y})  dimensions=#{width}x#{height} display=#{display.inspect} content=#{content}/>"
    end

    def update_computed(style)
      @computed.merge!(style)
    end

    private

    def initialize_defaults
      style.has_key?(:display) || style[:display] = :block
    end
  end


  class InputBox < Box
    attr_accessor :cursor_position

    def initialize(*args)
      super
      @cursor_offset_x = 0
      @cursor_position = OpenStruct.new(x: 0, y: 0)
    end

    def cursor_off
      @style.update(cursor: 'none')
    end

    def cursor_on
      @style.update(cursor: 'auto')
    end

    def content=(str)
      new_content = ANSIString.new(str)
      if @content != new_content
        old_content = @content
        @content = new_content
        emit :content_changed, old_content, @content
      end
    end

    def position=(position)
      @cursor_offset_x = position
      @cursor_position.x = @cursor_offset_x + @computed[:x]
      emit :cursor_position_changed, nil, @cursor_position.x
    end

    def update_computed(style)
      @computed.merge!(style)
      if style[:y] > 0
        @cursor_position.x = @computed[:width] #@computed[:width] - (style[:x] + @cursor_offset_x)
      else
        @cursor_position.x = style[:x] + @cursor_offset_x
      end
      @cursor_position.y = style[:y]
    end
  end

  require 'terminfo'
  require 'termios'
  require 'highline/system_extensions'
  class TerminalRenderer
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
      move_up_n_rows @y
      move_to_beginning_of_row

      cursor_position = input_box.cursor_position
      cursor_x = cursor_position.x
      cursor_y = cursor_position.y

      # TODO: make this work when lines wrap
      if cursor_x < 0 && cursor_y == 0
        cursor_x = terminal_width
        cursor_y -= 1
      elsif cursor_x >= terminal_width
        cursor_y  = cursor_x / terminal_width
        cursor_x -= terminal_width
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

    def dumb_render(object, reset: false)
      if reset
        @y = 0
        @previously_printed_lines.clear
      end
      @output.print @term_info.control_string "civis"
      move_up_n_rows @y
      move_to_beginning_of_row

      loop do
        break unless object.parent
        object = object.parent
      end

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

      printable_lines.zip(@previously_printed_lines) do |new_line, previous_line|
        if new_line != previous_line
          term_info.control "el"
          move_to_beginning_of_row
          @output.puts new_line
        else
          move_down_n_rows 1
        end
      end
      move_to_beginning_of_row
      clear_screen_down

      # calculate lines drawn so we know where we are
      lines_drawn = (printable_content.length / object_width.to_f).ceil
      @y = lines_drawn

      input_box = find_input_box(object.box)
      render_cursor(input_box)

      @previously_printed_lines = printable_lines
    end

    def find_input_box(dom_node)
      dom_node.children.detect do |child|
        child.is_a?(InputBox) || find_input_box(child)
      end
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
