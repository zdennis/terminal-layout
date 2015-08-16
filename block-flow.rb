require 'pry'

$z = File.open("/tmp/z.log", "w+")

$stdout.sync = true

class Layout
  def initialize(box, offset_x:0, offset_y:0)
    @box = box
    @x = offset_x
    @y = offset_y
  end

  def layout_floats(floats)
    floats.each do |fbox|
      if fbox.float == :left
        # only allow the float to be as wide as its parent
        if fbox.width > @box.width
          fbox.width = @box.width
        end

        # if we cannot fit on this line, go to the next
        if @x + fbox.width > @box.width
          @x = 0
          @y += 1
        end

        fbox.x = @x
        fbox.y = @y

        Layout.new(fbox, offset_x:@x, offset_y:@y).layout

        @x += fbox.width
      end
    end
  end

  def starting_x_for_current_y
    x = 0
    @box.children.select { |cbox| cbox.display == :float }.each do |fbox|
      next unless fbox.y >= @y && @y <= (fbox.y + fbox.height)
      x = [fbox.x + fbox.width, x].max
    end
    x
  end

  def layout
    floats = @box.children.select { |cbox| cbox.display == :float }
    layout_floats(floats)

    non_floats = @box.children.select { |cbox| cbox.display != :float }

    non_floats.each_with_index do |cbox, i|
      previous_box = i > 0 ? non_floats[i - 1] : nil

      if cbox.display == :block
        @x = starting_x_for_current_y

        if (previous_box && previous_box.display == :inline) || @x >= @box.width
          @y += 1
          @x = 0
        end

        cbox.width = (@box.width - @x)
        Layout.new(cbox, offset_x:@x, offset_y:@y).layout
        @box.height = (@box.height || 0) + cbox.height + (@box.content.to_s.length / @box.width.to_f).round
        cbox.x = @x
        cbox.y = @y

        @y += cbox.height
        @x = 0
      elsif cbox.display == :inline
        cbox.x = @x
        cbox.y = @y
        cbox.width = @box.width
        @y += (@x + cbox.content.length) / @box.width
        @x = (@x + cbox.content.length) % @box.width
      end
    end

    @box.children
  end
end

class Box
  attr_reader :children, :style, :content

  def initialize(content, children:[], style:nil)
    @style = style || { display: :block }
    @content = content
    @children = children
  end

  %w(width height display x y float).each do |method|
    define_method(method){ style[method.to_sym] }
    define_method("#{method}="){ |value| style[method.to_sym] = value }
  end

  def width
    style[:width] || 0
  end

  def height
    if style[:height]
      style[:height]
    elsif style[:width]
      (@content.to_s.length / style[:width].to_f).ceil
    else # auto
      0
    end
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
end

parent = Box.new(nil,
  children: [
    Box.new("<"*2, style:{display: :float, float: :left, width:3}),
    Box.new(">"*2, style:{display: :float, float: :left, width:3}),
    Box.new("A"*20, style: {display: :block}),
    Box.new("_"*3, style: {display: :inline}),
    Box.new("-"*3, style: {display: :inline}),
    Box.new("~"*3, style: {display: :inline}),
    Box.new("B", style: {display: :block},
      children: [
        Box.new("b"*10, style: {display: :block}, children:[
          Box.new("*"*3, style: {display: :inline}),
          Box.new("!"*3, style: {display: :inline}),
          Box.new("$"*3, style: {display: :inline}),
          Box.new("["*3, style: {display: :block})
        ]),
      ]),
    Box.new("C"*30, style: {display: :block}),
    Box.new("D"*20, style: {display: :block}),
    Box.new("E"*10, style: {display: :block})
  ],
  style: {
    display: :block,
    width: 10,
    height: nil
  }
)

require 'terminfo'
class TerminalRenderer
  attr_reader :term_info

  def initialize
    @term_info = TermInfo.new ENV["TERM"], $stdout
    # clear_screen
    @x, @y = 0, 0
  end

  def log(str)
    $z.puts str
  end

  def render(tree)
    tree.each_with_index do |cbox, i|
      previous_box = i > 0 ? tree[i-1] : nil
      if cbox.display == :block
        render_block cbox
      elsif cbox.display == :inline
        # if previous_box && previous_box.display == :block
          # needed_lines = cbox.y - (previous_box.y + previous_box.height) + 1
          # needed_lines.times{ $stdout.puts }
          # @y += needed_lines
        # end
        render_inline cbox
      elsif cbox.display == :float
        render_float cbox
      end
    end
  end

  def render_float(fbox)
    @x = fbox.x
    log "move to column #{fbox.x}"
    move_to_column fbox.x
    render_inline Box.new(fbox.content, style:{display: :inline, x:fbox.x, y:fbox.y})
    render(fbox.children)
  end

  def render_block(cbox)
    @x = cbox.x

    log "move to column #{@x}"
    move_to_column @x

    needed_lines = cbox.y - @y
    log "puts #{needed_lines} times (#{cbox.y} - #{@y})"
    needed_lines.times { $stdout.puts }
    @y = cbox.y

    if cbox.children.any?
      render(cbox.children)
      @x = cbox.x
      $stdout.puts
      @y += 1
    end

    @x = cbox.x

    render_inline(Box.new(cbox.content, style:{display: :inline, width: cbox.width, x:cbox.x, y:cbox.y}))
  end

  def render_inline(cbox)
    count = 0
    loop do
      if count >= cbox.content.length
        log "breaking because count >= cbox.content.length (#{count} >= #{cbox.content.length})  x:#{@x} y:#{@y}"
        break
      end

      if @x > cbox.x && cbox.width > 0 && (@x % (cbox.width + cbox.x)) == 0
        log "puts because inline content is at width (count % cbox.width) == 0   (#{count} % #{cbox.width}) == 0   x:#{@x} y:#{@y}"
        $stdout.puts
        @x = cbox.x
        @y += 1
      end

      log "print #{cbox.content[count].inspect}    x:#{@x} y:#{@y} count:#{count}"
      move_to_column @x

      $stdout.print cbox.content[count]
      count += 1
      @x += 1
    end

    log "Done inline: x:#{@x}  y:#{@y}"
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

layout_tree = Layout.new(parent).layout


TerminalRenderer.new.render(layout_tree)


def print_tree(tree, indent=0)
  tree.each do |box|
    print " " * indent
    puts box
    print_tree box.children, indent + 2
  end
end

print_tree layout_tree
# require 'pry'
# binding.pry
puts
