require 'ansi_string'

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

      @box.unsubscribe
      @box.on(:content_changed) do |old_content, new_content|
        @content = @box.content
        @parent.layout
        @renderer.render @parent
        # emit :foo
      end
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
      define_method("#{method}="){ |value| style[method.to_sym] = value }
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
      result = height.times.map { |n| (" " * width) }.join("\n")
      result = ANSIString.new(result)

      if content
        result[0...content.length] = content.dup.to_s
      end

      children.each do |child|
        rendered_content = child.render

        # Find the single point where this child's content should be placed.
        #  (child.y * width): make sure we take into account the row we're on
        #  plus (child.y): make sure take into account the number of newlines
        x = child.x + (child.y * width) + child.y
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
          if children.last.display == :inline && @current_x != 0
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
            chars_needed = available_width
            partial_content = cbox.content[content_i...(content_i + chars_needed)]
            chars_needed = partial_content.length
            self.children << render_object_for(cbox, content:partial_content, style: {display: :inline, x:@current_x, y: @current_y, width:chars_needed, height:1})

            content_i += chars_needed

            if chars_needed >= available_width
              @current_y += 1
              @current_x = starting_x_for_current_y
              available_width = ending_x_for_current_y - @current_x
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

    attr_accessor :style, :children, :content

    def initialize(style:{}, children:[], content:"")
      @style = style
      @children = children
      @content = ANSIString.new(content)

      initialize_defaults
    end

    %w(width height display x y float).each do |method|
      define_method(method){ style[method.to_sym] }
      define_method("#{method}="){ |value| style[method.to_sym] = value }
    end

    def content=(str)
      old = @content
      @content = ANSIString.new(str)
      emit :content_changed, old, @content
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

    private

    def initialize_defaults
      style.has_key?(:display) || style[:display] = :block
    end
  end


  require 'terminfo'
  require 'termios'
  class TerminalRenderer
    include EventEmitter

    attr_reader :term_info

    def initialize
      @term_info = TermInfo.new ENV["TERM"], $stdout
      # clear_screen
      @x, @y = 0, 0
    end

    def log(str)
      $z.puts str
    end

    def dumb_render(node)
      print @term_info.control_string "civis"

      loop do
        break unless node.parent
        node = node.parent
      end

      rendered_content = node.render
      printable_content = rendered_content.sub(/\s*\Z/m, '')

      clear_screen_down
      puts printable_content

      move_up_n_rows printable_content.lines.length
      move_to_beginning_of_row


      @y = printable_content.lines.length
      log "Y: #{@y}"
      log printable_content.inspect
      log ""
      # printable_lines = printable_content.lines
      # @y = render_object.offset.y + printable_lines.length - 1
      # @y += render_object.offset.y + printable_lines.length
      # log "Y is now #{@y}"
    end

    def render(render_object)
      return dumb_render(render_object)

      print @term_info.control_string "civis"

      offset = render_object.offset

      # rows_to_move = [@y - offset.y, 0].max
      rows_to_move = @y - offset.y
      log "ROWS TO MOVE UP: #{rows_to_move}  Y is #{@y}   OFFSET IS #{offset.y}"
      if rows_to_move > 0
        move_up_n_rows rows_to_move
        # @y -= rows_to_move
      else
        move_down_n_rows rows_to_move.abs
        # @y += rows_to_move
      end
      move_to_column offset.x

      rendered_content = render_object.render

      printable_content = rendered_content.sub(/\s*\Z/m, '')
      print printable_content

      printable_lines = printable_content.lines
      @y = render_object.offset.y + printable_lines.length - 1
      # @y += render_object.offset.y + printable_lines.length
      log "Y is now #{@y}"
    ensure
      # print @term_info.control_string "cnorm"
    end

    def clear_to_beginning_of_line ; term_info.control "el1" ; end
    def clear_screen ; term_info.control "clear" ; end
    def clear_screen_down ; term_info.control "ed" ; end
    def move_to_beginning_of_row ; move_to_column 0 ; end
    def move_left ; move_left_n_characters 1 ; end
    def move_left_n_characters(n) ; term_info.control "cub1" ; end
    def move_right_n_characters(n) ; term_info.control "cuf1" ; end
    def move_to_column_and_row(column, row) ; term_info.control "cup", column, row ; end
    def move_to_column(n) ; term_info.control "hpa", n ; end
    def move_up_n_rows(n) ; n.times { term_info.control "cuu1" } ; end
    def move_down_n_rows(n) ; n.times { term_info.control "cud1" } ; end
  end
end
