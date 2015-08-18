require 'pry'

$z = File.open("/tmp/z.log", "w+")
$z.sync = true

$stdout.sync = true

class Layout
  def initialize(box, offset_x:0, offset_y:0)
    @box = box
    @x = offset_x
    @y = offset_y
  end

  def layout_float(fbox)
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

  def starting_x_for_current_y
    x = 0
    @box.children.select { |cbox| cbox.display == :float }.each do |fbox|
      next unless fbox.y && fbox.y <= @y && (fbox.y + fbox.height) >= @y
      x = [fbox.x + fbox.width, x].max
    end
    x
  end

  def layout
    @tree = []

    @box.children.each_with_index do |cbox, i|
      previous_box = i > 0 ? @box.children[i - 1] : nil
      if cbox.display == :float
        layout_float cbox

        @tree.push cbox
      elsif cbox.display == :block
        if previous_box && previous_box.display == :inline
          @y += 1
        end
        @x = starting_x_for_current_y

        cbox.width = (@box.width - @x)
        new_box = Box.new("", style: cbox.style)
        new_box.children = [Box.new(cbox.content, children:[], style: {display: :inline})].concat cbox.children
        new_box.children = Layout.new(new_box, offset_x:@x, offset_y:@y).layout
        new_box.x = @x
        new_box.y = @y

        new_box.height = (new_box.children.map(&:y).max - new_box.y) +  new_box.children.map(&:height).max
        #@box.height = (@box.height || 0) + new_box.height + (@box.content.to_s.length / @box.width.to_f).round

        @y += new_box.height
        @x = 0

        @tree.push new_box
      elsif cbox.display == :inline
        if @x == 0
          @x = starting_x_for_current_y
        end


        content_i = 0
        content = ""

        loop do
          chars_needed = @box.width - @x
          partial_content = cbox.content[content_i..(content_i + chars_needed)]
          chars_needed = partial_content.length
          @tree << Box.new(partial_content, children:[], style: {display: :inline, x:@x, y: @y, width:chars_needed, height:1})

          content_i += chars_needed

          if @x + chars_needed > @box.width
            @y += 1
            @x = starting_x_for_current_y
          else
            @x += chars_needed
          end

          break if content_i >= cbox.content.length
        end
      end
    end

    @box.height = @box.height || (@box.children.map(&:y).max) - (@box.y || 0)

    @tree
  end
end

class Box
  attr_accessor :children, :style, :content

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
    style[:width] || content.length
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
        @x = cbox.x
        log "move to column #{@x}"
        move_to_column @x

        needed_lines = cbox.y - @y
        log "inline puts #{needed_lines} times"
        needed_lines.times{ $stdout.puts }
        @y = cbox.y

        render_inline cbox
      elsif cbox.display == :float
        needed_lines = cbox.y - @y
        log "float puts #{needed_lines} times"
        needed_lines.times{ $stdout.puts }
        @y = cbox.y

        render_float cbox
      end
    end
  end

  def render_float(fbox)
    @x = fbox.x
    log "move to column #{fbox.x}"
    move_to_column fbox.x

    render_inline Box.new(fbox.content, style:{
      display: :inline,
      width: fbox.width,
      height: fbox.height,
      x:fbox.x,
      y:fbox.y
    })

    render(fbox.children)
  end

  def render_block(cbox)
    @x = cbox.x
    log "move to column #{@x}"
    move_to_column @x

    needed_lines = cbox.y - @y
    log "puts #{needed_lines} times (#{cbox.y} - #{@y})"
    if needed_lines >= 0
      needed_lines.times { $stdout.puts }
    else
      move_up_n_rows needed_lines.abs
    end
    @y = cbox.y

    if cbox.children.any?
      render(cbox.children)
    end

    @x = cbox.x

    render_inline(Box.new(cbox.content, style:{display: :inline, width: cbox.width, x:cbox.x, y:cbox.y}))
  end

  def render_inline(cbox)
    count = 0
    rel_count = 0
    loop do
      if count >= cbox.content.length
        log "breaking because count >= cbox.content.length (#{count} >= #{cbox.content.length})  x:#{@x} y:#{@y}  count:#{count}"
        break
      end

      # binding.pry if cbox.content =~ />/
      if rel_count >= cbox.width
      # if @x > cbox.x && cbox.width > 0 && (@x % (cbox.width + cbox.x)) == 0
        log "puts because inline content is at width (count % cbox.width) == 0   (#{count} % #{cbox.width}) == 0   x:#{@x} y:#{@y}   count:#{count}"
        $stdout.puts
        rel_count = 0
        @x = cbox.x
        @y += 1
      end

      log "print #{cbox.content[count].inspect}    x:#{@x} y:#{@y} count:#{count}"
      move_to_column @x

      $stdout.print cbox.content[count]
      count += 1
      rel_count += 1
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



parent = Box.new(nil,
  children: [
    Box.new("<"*5, style:{display: :float, float: :left, width:5}),
    Box.new(">"*15, style:{display: :float, float: :left, width:5}),
    Box.new("A"*20, style: {display: :block}),
    Box.new("_"*6, style: {display: :inline}),
    Box.new("-"*6, style: {display: :inline}),
    Box.new("~"*9, style: {display: :inline}),
    Box.new("B", style: {display: :block},
      children: [
        Box.new("b"*10, style: {display: :block}, children:[
          Box.new("*"*3, style: {display: :inline}),
          Box.new("!"*3, style: {display: :inline}),
          Box.new("$"*3, style: {display: :inline}),
          Box.new("["*3, style: {display: :block})
        ]),
      ]),
    Box.new("C"*60, style: {display: :block}),
    Box.new("D"*20, style: {display: :block}),
    Box.new("E"*10, style: {display: :block})
  ],
  style: {
    display: :block,
    width: 60,
    height: nil
  }
)


layout_tree = Layout.new(parent).layout


def print_tree(tree, indent=0)
  tree.each do |box|
    print " " * indent
    puts box
    print_tree box.children, indent + 2
  end
end


print_tree layout_tree
TerminalRenderer.new.render(layout_tree)


# print_tree layout_tree
# require 'pry'
# binding.pry
puts
