require 'ostruct'
require 'ansi_string'
require 'treefell'
require 'terminal_layout/event_emitter'
require 'terminal_layout/renderer'

module TerminalLayout
  Dimension = Struct.new(:width, :height)
  Position = Struct.new(:x, :y)

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
        @box.computed[method.to_sym] = value
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
      "<#{self.class.name} position=(#{x},#{y}) dimensions=#{width}x#{height} content=#{content} name=#{@box.name}/>"
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

          render_object = render_object_for(cbox, content:nil, style: {
            x: @current_x,
            y: @current_y,
            width: (cbox.width || available_width)
          })
          render_object.layout

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
            self.children << render_object_for(
              cbox,
              content:partial_content,
              style: {
                display: :inline,
                x: @current_x,
                y: @current_y,
                width:chars_needed,
                height:1
              }
            )

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

      self.children.each do |child|
        child.box.computed[:x] += x
        child.box.computed[:y] += y
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

    attr_accessor :style, :children, :content, :computed, :name

    def initialize(style:{}, children:[], content:"")
      @style = style
      @children = children
      @content = ANSIString.new(content)
      @computed = {}

      initialize_defaults
      subscribe_to_events_on_children
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
      unsubscribe_from_events_on_children
      old_children = @children
      @children = new_children
      subscribe_to_events_on_children
      emit :child_changed, old_children, new_children
    end

    def find_child_of_type(type, &block)
      children.each do |child|
        matches = child.is_a?(type)
        matches &= block.call(child) if matches && block
        return child if matches
        child_matches = child.find_child_of_type(type, &block)
        return child_matches if child_matches
      end
      nil
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
      "<#{self.class}##{object_id} position=(#{x},#{y}) dimensions=#{width}x#{height} display=#{display.inspect} content=#{content} name=#{@name}/>"
    end

    def update_computed(style)
      @computed.merge!(style)
    end

    private

    def initialize_defaults
      style.has_key?(:display) || style[:display] = :block
    end

    private

    def unsubscribe_from_events_on_children
      @children.each do |child|
        child.unsubscribe
      end
    end

    def subscribe_to_events_on_children
      @children.each do |child|
        child.on(:content_changed) do |*args|
          emit :content_changed
        end
        child.on(:child_changed) do |*args|
          emit :child_changed
        end
        child.on(:position_changed) do |*args|
          emit :position_changed
        end
        child.on(:focused_changed) do |*args|
          emit :focused_changed, *args
        end
      end
    end
  end

  class InputBox < Box
    # cursor_position is the actual coordinates on the screen of where then
    # cursor is rendered
    attr_accessor :cursor_position

    # position is the desired X-position of the cursor if everything was
    # displayed on a single line
    attr_accessor :position

    def focus!
      return if @focused
      @focused = true
      emit :focus_changed, !@focused, @focused
    end

    def remove_focus!
      return unless @focused
      @focused = false
      emit :focus_changed, !@focused, @focused
    end

    def focused? ; !!@focused ; end

    def initialize(*args)
      super
      @computed = { x: 0, y: 0 }
      @cursor_position = OpenStruct.new(x: 0, y: 0)
      @position = 0
      @focused = false
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

    def position=(new_position)
      old_position = @position
      @position = new_position
      emit :position_changed, old_position, @position
    end

    def update_computed(style)
      # if the style being updated has a y greater than 0
      # then it's because the renderable content for the input box
      # spans multiple lines. We do not want to update the x/y position(s)
      # in this instance. We want to keep the original starting x/y.
      if style[:y] && style[:y] > 0
        style = style.dup.delete_if { |k,_| [:x, :y].include?(k) }
      end
      @computed.merge!(style)
    end
  end

end
