module TerminalLayout
  Dimension = Struct.new(:width, :height)
  Position = Struct.new(:x, :y)

  class RenderObject
    attr_accessor :box, :style, :children, :content

    def initialize(box, content:nil, style:{x:nil, y:nil})
      @box = box
      @content = content
      @children = []
      @style = style
      style[:x] || style[:x] = 0
      style[:y] || style[:y] = 0
    end

    def starting_x_for_current_y
      children.map do |child|
        next unless child.float == :left
        next unless child.y && child.y <= @current_y && (child.y + child.height - 1) >= @current_y

        [child.x + child.width, x].max
      end.compact.max || 0
    end

    def ending_x_for_current_y
      children.map do |child|
        next unless child.float == :right
        next unless child.y && child.y <= @current_y && (child.y + child.height - 1) >= @current_y

        [child.x, @box.width].min
      end.compact.min || @box.width
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

    def layout
      self.children = []

      @current_x = 0
      @current_y = 0

      if content
        available_width = ending_x_for_current_y - @current_x
        new_parent = Box.new(nil, {style: @box.style.dup.merge(width: available_width)})
        inline_box = Box.new(content, {style: :inline})
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
          @current_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - @current_x

          if cbox.width && cbox.width > available_width
            @current_y += 1
            @current_x = starting_x_for_current_y
            available_width = ending_x_for_current_y - @current_x
          end

          render_object = render_object_for(cbox, style: {width: (cbox.width || available_width)})
          render_object.layout
          render_object.x = @current_x
          render_object.y = @current_y
          render_object.height = cbox.height

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

            if @current_x + chars_needed >= available_width
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

      if children.length >= 2
        last_child = children.max{ |child| child.y }
        self.height = last_child.y + last_child.height
      elsif children.length == 1
        self.height = self.children.first.height
      else
        self.height = @box.height || 0
      end

      self.children
    end

    def layout_float(fbox)
      # only allow the float to be as wide as its parent
      if fbox.width > @box.width
        fbox.width = @box.width
      end

      if fbox.float == :left
        # if we cannot fit on this line, go to the next
        if @current_x + fbox.width > @box.width
          @current_x = 0
          @current_y += 1
        end

        fbox.x = @current_x
        fbox.y = @current_y

        render_object = render_object_for(fbox, style: {height: fbox.height})
        render_object.layout

        @current_x += fbox.width
        return render_object
      elsif fbox.float == :right
        # loop in case there are left floats on the left as we move down rows
        loop do
          starting_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - starting_x

          # if we cannot fit on this line, go to the next
          width_needed = starting_x + fbox.width
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

        render_object = render_object_for(fbox, style: {height: fbox.height})
        render_object.layout

        # reset X back to what it should be
        @current_x = starting_x_for_current_y
        return render_object
      end
    end

    def render_object_for(cbox, content:nil, style:{})
      case cbox.display
      when :block
        BlockRenderObject.new(cbox, style: {width:@box.width}.merge(style))
      when :inline
        InlineRenderObject.new(cbox, content: content, style: style)
      when :float
        FloatRenderObject.new(cbox, style: {x: @current_x, y: @current_y, float: cbox.float}.merge(style))
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

  class Layout
    def layout
      laid_out_tree = []

      @current_x = @x
      @current_y = @y

      @box.children.each do |cbox|
        if cbox.display == :block
          @current_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - @current_x

          box2layout = Box.new(style: cbox.style.dup)
          box2layout.width = @box.width
          box2layout.children = cbox.children.dup
          box2layout.x = @current_x
          box2layout.y = @current_y
          box2layout.children = Layout.new(box2layout).layout
          box2layout.height = cbox.height

          next if [nil, 0].include?(box2layout.width) || [nil, 0].include?(box2layout.height)

          laid_out_tree.push box2layout
          @current_x = 0
          @current_y += [box2layout.height, 1].max
        elsif cbox.display == :inline
          @current_x = starting_x_for_current_y if @current_x == 0
          available_width = ending_x_for_current_y - @current_x

          content_i = 0
          content = ""

          loop do
            chars_needed = available_width
            partial_content = cbox.content[content_i...(content_i + chars_needed)]
            chars_needed = partial_content.length
            laid_out_tree << Box.new(content:partial_content, children:[], style: {display: :inline, x:@current_x, y: @current_y, width:chars_needed, height:1})

            content_i += chars_needed

            if @current_x + chars_needed > available_width
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

      laid_out_tree
    end
  end

  class Box
    attr_accessor :style, :children, :content

    def initialize(style:{}, children:[], content:"")
      @style = style
      @children = children
      @content = content

      initialize_defaults
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
      "<Box##{object_id} position=(#{x},#{y})  dimensions=#{width}x#{height} display=#{display.inspect} content=#{content}/>"
    end

    private

    def initialize_defaults
      style.has_key?(:display) || style[:display] = :block
    end
  end
end