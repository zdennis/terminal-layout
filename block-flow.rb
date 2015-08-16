require 'pry'

class Layout
  def initialize(box)
    @box = box
    @x = 0
    @y = 0
  end

  def layout
    @box.children.each do |cbox|
      if cbox.display == :block
        cbox.width = @box.width
        Layout.new(cbox).layout
        @box.height = cbox.height
        cbox.x = @x
        cbox.y = @y
        @y += 1
        @x = 0
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
      (@content.length / style[:width].to_f).ceil
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
    "<Box position=(#{x},#{y})  dimensions=#{width}x#{height} content=#{content}/>"
  end
end

parent = Box.new(nil,
  children: [
    Box.new("A"*20, style: {display: :block}),
    Box.new("B"*20, style: {display: :block}),
    Box.new("C"*30, style: {display: :block}),
    Box.new("D"*20, style: {display: :block}),
    Box.new("E"*10, style: {display: :block})
  ],
  style: {
    display: :block,
    width: 5,
    height: nil
  }
)

require 'terminfo'
class TerminalRenderer
  attr_reader :term_info

  def initialize
    @term_info = TermInfo.new ENV["TERM"], $stdout
    clear_screen
  end

  def render(tree)
    tree.each_with_index do |cbox, i|
      x = 0
      y = (i == 0) ? 0 : cbox.y - tree[i-1].y

      move_to_column x
      y.times { $stdout.puts }

      count = 0
      loop do
        $stdout.print cbox.content[count]
        count += 1
        x += 1
        break if count >= cbox.content.length

        if x >= cbox.width
          $stdout.puts
          x = 0
          y += 1
        end
        break if y > cbox.height
      end
    end
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

puts
puts layout_tree
# require 'pry'
# binding.pry
puts
