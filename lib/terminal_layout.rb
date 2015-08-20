module TerminalLayout
  Dimension = Struct.new(:width, :height)
  Position = Struct.new(:x, :y)

  class Layout
    def initialize(box, offset_x:0, offset_y:0)
      @box = box
      @x = offset_x
      @y = offset_y
    end

    def starting_x_for_current_y ; 0; end
    def ending_x_for_current_y ; @box.width ; end

    def layout
      laid_out_tree = []

      current_x = @x
      current_y = @y

      @box.children.each do |cbox|
        if cbox.display == :block
          current_x = starting_x_for_current_y
          available_width = ending_x_for_current_y - current_x

          box2layout = Box.new(style: cbox.style.dup)
          box2layout.width = @box.width
          box2layout.children = cbox.children.dup
          box2layout.x = current_x
          box2layout.y = current_y
          box2layout.children = Layout.new(box2layout).layout
          box2layout.height = cbox.height

          # new_box = Box.new("", style: cbox.style.merge(width: cbox.width))
          # new_box.children = [Box.new(cbox.content, children:[], style: {display: :inline})].concat cbox.children
          # new_box.children = Layout.new(new_box, offset_x:@x, offset_y:@y).layout
          # new_box.x = @x
          # new_box.y = @y
          #
          # new_box.height = (new_box.children.map(&:y).max - new_box.y) +  new_box.children.map(&:height).max
          #
          # @y += new_box.height
          # @x = 0

          next if [nil, 0].include?(box2layout.width) || [nil, 0].include?(box2layout.height)

          laid_out_tree.push box2layout
          current_x = 0
          current_y += [box2layout.height, 1].max
        elsif cbox.display == :inline
          current_x = starting_x_for_current_y if current_x == 0
          available_width = ending_x_for_current_y - current_x

          content_i = 0
          content = ""

          loop do
            chars_needed = available_width
            partial_content = cbox.content[content_i...(content_i + chars_needed)]
            chars_needed = partial_content.length
            laid_out_tree << Box.new(content:partial_content, children:[], style: {display: :inline, x:current_x, y: current_y, width:chars_needed, height:1})

            content_i += chars_needed

            if current_x + chars_needed > available_width
              current_y += 1
              current_x = starting_x_for_current_y
              available_width = ending_x_for_current_y - current_x
            else
              current_x += chars_needed
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

    %w(width height display x y).each do |method|
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
      "<Box position=(#{x},#{y})  dimensions=#{width}x#{height} display=#{display.inspect} content=#{content}/>"
    end

    private

    def initialize_defaults
      style.has_key?(:display) || style[:display] = :block
    end
  end
end
