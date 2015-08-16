require 'pry'

$z = File.open("/tmp/z.log", "w+")

$stdout.sync = true

class Layout
  def initialize(box, offset_x:0, offset_y:0)
    @box = box
    @x = offset_x
    @y = offset_y
  end

  def layout
    @box.children.each_with_index do |cbox, i|
      previous_box = i > 0 ? @box.children[i - 1] : nil

      if cbox.display == :block
        @x = 0
        @y += 1 if previous_box && previous_box.display == :inline
        cbox.width = @box.width
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
  end
end

class Box
  attr_reader :children, :style, :content

  def initialize(content, children:[], style:nil)
    @style = style || { display: :block }
    @content = content
    @children = children
  end

  %w(width height display x y).each do |method|
    define_method(method){ style[method.to_sym] }
    define_method("#{method}="){ |value| style[method.to_sym] = value }
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
    width: 80,
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
        if previous_box && previous_box.display == :block
          needed_lines = cbox.y - (previous_box.y + previous_box.height) + 1
          needed_lines.times{ $stdout.puts }
          @y += needed_lines
        end
        render_inline cbox
      end
    end
  end

  def render_block(cbox)
    @x = 0
    log "move to column #{@x}"
    move_to_column @x

    needed_lines = cbox.y - @y
    log "puts #{needed_lines} times (#{cbox.y} - #{@y})"
    needed_lines.times { $stdout.puts }
    @y = cbox.y

    if cbox.children.any?
      render(cbox.children)
      @x = 0
      $stdout.puts
      @y += 1
    end

    count = 0
    loop do
      log "print #{cbox.content[count].inspect}    x:#{@x} y:#{@y} count:#{count}"
      $stdout.print cbox.content[count]
      count += 1
      @x += 1

      if count >= cbox.content.length
        log "breaking because count >= cbox.content.length (#{count} >= #{cbox.content.length})  x:#{@x} y:#{@y}"
        break
      end

      if @x >= cbox.width
        log "puts because x >= cbox.width (#{@x} >= #{cbox.width})    x:#{@x} y:#{@y}"
        $stdout.puts
        @x = 0
        @y += 1
      end

      if @y > (cbox.height + cbox.y)
        log "break because y > (cbox.height + cbox.y) (#{@y} > (#{cbox.height} + #{cbox.y})     x:#{@x} y:#{@y}"
        break
      end
    end
    @x = 0
  end

  def render_inline(cbox)
    count = 0
    loop do
      if count >= cbox.content.length
        # binding.pry
        log "breaking because count >= cbox.content.length (#{count} >= #{cbox.content.length})  x:#{@x} y:#{@y}"
        break
      end

      if @x > 0 && (@x % cbox.width) == 0
        log "puts because inline content is at width (count % cbox.width) == 0   (#{count} % #{cbox.width}) == 0   x:#{@x} y:#{@y}"
        $stdout.puts
        @x = 0
        @y += 1
      end

      log "print #{cbox.content[count].inspect}    x:#{@x} y:#{@y} count:#{count}"
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
