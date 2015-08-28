require 'net/http'
require 'json'

post_number = 1

require 'pry'
$LOAD_PATH << "lib"
require "terminal_layout"
require 'term/ansicolor'

Color = Term::ANSIColor


left_status = Color.yellow("[YOUR STATUS LEFT]")
prompt = "This is my very special prompt> "
right_status = Color.blue("EVERYTHING LOOKS GOOD MY FRIEND!")

left_status_box = TerminalLayout::Box.new(content: left_status, style: {display: :inline})
right_status_box = TerminalLayout::Box.new(content: right_status, style: {display: :inline})

bottom_left_status_box = TerminalLayout::Box.new(content: left_status.dup, style: {display: :inline})
bottom_right_status_box = TerminalLayout::Box.new(content: right_status.dup, style: {display: :inline})

hard_status_box = TerminalLayout::Box.new(content: "^^^^^^^^^^^^^^^^^^^^^^^ HARD STATUS ^^^^^^^^^^^^^^^^^^")


dom = TerminalLayout::Box.new(children:[
  left_status_box,
  TerminalLayout::Box.new(style: {display: :float, float: :right, width: right_status.length},
    children: [
      right_status_box
    ]),
  TerminalLayout::Box.new(content: prompt, style: {display: :inline}),
  TerminalLayout::Box.new(content: "ls | grep foo", style: {display: :inline}),
  hard_status_box,
  TerminalLayout::Box.new(style: {display: :float, float: :left, width: left_status.length},
    children: [
      bottom_left_status_box
    ]),
  TerminalLayout::Box.new(style: {display: :float, float: :right, width: right_status.length},
    children: [
      bottom_right_status_box
    ]),
])

$z = File.open("/tmp/z.log", "w+")
$z.sync = true

terminal_renderer = TerminalLayout::TerminalRenderer.new

render_tree = TerminalLayout::RenderTree.new(dom, parent: nil, style: {width:178, height:44}, renderer: terminal_renderer)
render_tree.layout
terminal_renderer.render(render_tree)

sleep 0.75
left_status_box.content = Color.red("[UPDATED LEFT STATUS]")
sleep 0.5

dirs = (Dir[ENV["HOME"] + "/*"] * 100).to_enum

b = "a"
c = 12345
# sleep 2
loop do
  right_status_box.content = "[#{Time.now}]"
  sleep 0.25

  bottom_left_status_box.content = b.succ!
  sleep 0.25

  bottom_right_status_box.content = (c+=1).to_s
  sleep 0.25

  left_status_box.content = "[" + dirs.next + "]"
  sleep 0.25

  sample_post = JSON.parse Net::HTTP.get(URI("http://jsonplaceholder.typicode.com/posts/#{post_number+=1}"))
  title = sample_post["title"]
  length = 178
  num_spaces = (length - title.length) / 2
  str = "#{' ' * num_spaces}#{Color.green(sample_post['title'])}#{' ' * num_spaces}"
  $c = true
  hard_status_box.content = "#{' ' * num_spaces}#{Color.green(sample_post['title'])}#{' ' * num_spaces}"
end
puts "DIED?"
