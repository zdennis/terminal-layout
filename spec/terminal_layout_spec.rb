require 'spec_helper'
require 'pry'

def print_tree(render_tree, indent=0)
  render_tree.children.each do |box|
    print " " * indent
    puts box
    print_tree box, indent + 2
  end
end

def find_first_in_tree(tree, comparator_proc)
  tree.children.each do |node|
    return node if comparator_proc.call(node)
    find_first_in_tree node, comparator_proc
  end
  nil
end

def find_all_in_tree(tree, comparator_proc)
  return nil if tree.children.empty?
  tree.children.inject([]) do |results, node|
    if comparator_proc.call(node)
      results.push node
    else
      results.push find_first_in_tree(node, comparator_proc)
    end
    results.compact
  end
end


module TerminalLayout

  describe "Laying things out" do
    subject(:render_tree){ RenderTree.new(view, style:style).tap{ |rt| rt.layout } }
    let(:view){ Box.new(style: style, children: children) }
    let(:style){ raise(NotImplementedError, "Must provide :children") }
    let(:children){ raise(NotImplementedError, "Must provide :children") }

    def first_rendered(box, parent: render_tree)
      find_first_in_tree(parent, ->(node){ node.box == box })
    end

    def all_rendered(box, parent: render_tree)
      find_all_in_tree(parent, ->(node){ node.box == box })
    end

    after(:each) do |example|
      if example.exception
        puts
        puts " #{example.location} #{example.description}"
        print_tree render_tree
      end
    end

    describe "normal block flow - vertical stacking" do
      context "with one block child" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_a] }
        let(:block_a){ Box.new(style: {display: :block, height: 1}) }
        let(:rendered_element){ first_rendered(block_a) }

        it "positions the box at (0,0) with the same width as its containing box" do
          expect(rendered_element.position).to eq(Position.new(0, 0))
          expect(rendered_element.size).to eq(Dimension.new(10, 1))
        end
      end

      context "block with content" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_a] }
        let(:block_a){ Box.new(content: "Foobar", style: {display: :block}) }
        let(:rendered_element){ first_rendered(block_a) }

        it "sets the height" do
          expect(rendered_element.position).to eq(Position.new(0, 0))
          expect(rendered_element.size).to eq(Dimension.new(10, 1))
        end
      end

      context "block with height set" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_a] }
        let(:block_a){ Box.new(style: {display: :block, height:4}, children:[
            Box.new(content: "Foobar", style: {display: :inline})
        ])}
        let(:rendered_element){ first_rendered(block_a) }

        it "doesn't shrink the height when the content needs less" do
          expect(block_a.height).to eq 4
        end

        it "doesn't grow the height when the content needs more" do
          block_a.content = "Foobar" * 100
          expect(block_a.height).to eq 4
        end

        it "doesn't affect the height of the render tree" do
          expect(render_tree.height).to eq 10
        end
      end

      context "with multiple block children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_a, block_b] }
        let(:block_a){ Box.new(style: {display: :block, height: 1}) }
        let(:block_b){ Box.new(style: {display: :block, height: 1}) }

        let(:rendered_element_a){ first_rendered(block_a) }
        let(:rendered_element_b){ first_rendered(block_b) }

        it "stacks the boxes vertically with the widths matching the containing box" do
          expect(render_tree.children.length).to eq(2)

          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(10, 1))

          expect(rendered_element_b.position).to eq(Position.new(0, 1))
          expect(rendered_element_b.size).to eq(Dimension.new(10, 1))
        end
      end

      context "with a block child that has 0 height" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_0_height] }
        let(:block_0_height){ Box.new(style: {display: :block, height: 0}) }

        it "doesn't include it in the layout render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end

      context "with a block child that has 0 width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_0_width] }
        let(:block_0_width){ Box.new(style: {display: :block, width: 0}) }

        it "doesn't include it in the layout render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end
    end

    describe "normal flow - inline elements" do
      context "with multiple inline children that fit within the width of the parent" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [inline_a, inline_b] }
        let(:inline_a){ Box.new(content:"ABC", style: {display: :inline}) }
        let(:inline_b){ Box.new(content:"DEFGHIJ", style: {display: :inline}) }

        let(:rendered_element_a){ first_rendered(inline_a) }
        let(:rendered_element_b){ first_rendered(inline_b) }

        it "horizontally lays out the two boxes with the width matching their respective content's length" do
          expect(render_tree.children.length).to eq(2)

          expect(rendered_element_a.content).to eq("ABC")
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(3, 1))

          expect(rendered_element_b.content).to eq("DEFGHIJ")
          expect(rendered_element_b.position).to eq(Position.new(3, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(7, 1))
        end
      end

      context "with multiple inline children that do not fit within the width of the parent" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [inline_a, inline_b] }
        let(:inline_a){ Box.new(content:"ABCDEFG", style: {display: :inline}) }
        let(:inline_b){ Box.new(content:"HIJKLMNO", style: {display: :inline}) }

        let(:rendered_element_a){ first_rendered(inline_a) }
        let(:rendered_elements_b){ all_rendered(inline_b) }

        it "horizontally lays out the two boxes wrapping lines as needed" do
          expect(render_tree.children.length).to eq(3)

          # row 1
          expect(rendered_element_a.content).to eq("ABCDEFG")
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(7, 1))

          expect(rendered_elements_b[0].content).to eq("HIJ")
          expect(rendered_elements_b[0].position).to eq(Position.new(7, 0))
          expect(rendered_elements_b[0].size).to eq(Dimension.new(3, 1))

          # row 2
          expect(rendered_elements_b[1].content).to eq("KLMNO")
          expect(rendered_elements_b[1].position).to eq(Position.new(0, 1))
          expect(rendered_elements_b[1].size).to eq(Dimension.new(5, 1))
        end
      end
    end

    describe "normal flow - float left" do
      context "with a single element float left without a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left}) }

        it "doesn't include the element in the render render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end

      context "with a single element float left without a height" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left, width: 1}) }

        it "doesn't include the element in the render render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end

      context "a float left element without a height that has a block child" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left, width: 1}, children: [block_b]) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          expect(rendered_element_a.height).to eq(1)
        end
      end

      context "a float left element without a height that has multiple block children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left, width: 10}, children: [block_b, block_c]) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }
        let(:block_c){ Box.new(style: {width: 5, height: 4, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          expect(rendered_element_a.height).to eq(5)
        end
      end

      context "a float left element without a height that has inline children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left, width: 5}, children: [inline_b]) }
        let(:inline_b){ Box.new(content: "ABCDEFGHIJK", style: {display: :inline}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          # Line 1: ABCDE, Line 2: FGHIJ, Line 3: K
          expect(rendered_element_a.height).to eq(3)
        end
      end

      context "with a single element float left with a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){  Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "includes the element at the left-most position for the current row" do
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(5, 1))
        end
      end

      context "with a float left followed by a block element" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, block_b] }
        let(:float_a){ Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(block_b) }

        context "and they both fit on the same line" do
          it "puts the float left element before the block element" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(0, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # block
            expect(rendered_element_b.position).to eq(Position.new(5, 0))
            expect(rendered_element_b.size).to eq(Dimension.new(5, 1))
          end
        end

        context "and they do not fit on the same line" do
          before do
            block_b.width = 6
          end

          it "puts the block element on the next line when they both dont fit" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(0, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # block
            expect(rendered_element_b.position).to eq(Position.new(0, 1))
            expect(rendered_element_b.size).to eq(Dimension.new(6, 1))
          end
        end
      end

      context "with a float left followed by an block" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, inline_b] }
        let(:float_a){ Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }
        let(:inline_b){ Box.new(content: "ABCD", style: {height: 1, display: :inline}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(inline_b) }

        context "and they both fit on the same line" do
          it "puts it before inline elements on the same line" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(0, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # inline
            expect(rendered_element_b.position).to eq(Position.new(5, 0))
            expect(rendered_element_b.size).to eq(Dimension.new(4, 1))
          end
        end

        context "and they do not fit on the same line" do
          before do
            inline_b.content = "ABCDEFGHIJ"
          end

          let(:rendered_elements_b){ all_rendered(inline_b) }

          it "wraps the text onto the next line" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(0, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # inline
            expect(rendered_elements_b[0].position).to eq(Position.new(5, 0))
            expect(rendered_elements_b[0].size).to eq(Dimension.new(5, 1))

            expect(rendered_elements_b[1].position).to eq(Position.new(0, 1))
            expect(rendered_elements_b[1].size).to eq(Dimension.new(5, 1))
          end
        end
      end

      context "with multiple elements floated left" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, float_b, float_c, float_d] }
        let(:float_a){ Box.new(style: {width: 3, height: 1, display: :float, float: :left}) }
        let(:float_b){ Box.new(style: {width: 3, height: 1, display: :float, float: :left}) }
        let(:float_c){ Box.new(style: {width: 3, height: 1, display: :float, float: :left}) }
        let(:float_d){ Box.new(style: {width: 3, height: 1, display: :float, float: :left}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(float_b) }
        let(:rendered_element_c){ first_rendered(float_c) }
        let(:rendered_element_d){ first_rendered(float_d) }

        it "places them horizontally next to each other" do
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_b.position).to eq(Position.new(3, 0))
          expect(rendered_element_c.position).to eq(Position.new(6, 0))
        end

        it "wraps floats that don't fit on the current line to the next line" do
          expect(rendered_element_d.position).to eq(Position.new(0, 1))
        end
      end

      context "with a float left element that is taller than a single line" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, block_b, block_c] }
        let(:float_a){ Box.new(style: {width: 3, height: 5, display: :float, float: :left}) }
        let(:block_b){ Box.new(style: {width: 3, height: 2, display: :block}) }
        let(:block_c){ Box.new(style: {width: 3, height: 2, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(block_b) }
        let(:rendered_element_c){ first_rendered(block_c) }

        it "spans multiple lines" do
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(3, 5))
        end

        it "positions block elements next to the float on all lines" do
          expect(rendered_element_b.position).to eq(Position.new(3, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(3, 2))

          expect(rendered_element_c.position).to eq(Position.new(3, 2))
          expect(rendered_element_c.size).to eq(Dimension.new(3, 2))
        end
      end

      context "nested floats" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {width: 3, height: 5, display: :float, float: :left}, children: [
          float_b
        ])}
        let(:float_b){ Box.new(style: {width: 3, height: 5, display: :float, float: :left}, children: [
          float_c
        ])}
        let(:float_c){ Box.new(style: {width: 3, height: 5, display: :float, float: :left}, children: [
          float_d,
          block_e
        ])}
        let(:float_d){ Box.new(style: {width: 2, height: 5, display: :float, float: :left}) }
        let(:block_e){ Box.new(style: {width: 1, height: 5, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(float_b, parent: rendered_element_a) }
        let(:rendered_element_c){ first_rendered(float_c, parent: rendered_element_b) }
        let(:rendered_element_d){ first_rendered(float_d, parent: rendered_element_c) }
        let(:rendered_element_e){ first_rendered(block_e, parent: rendered_element_c) }

        it "nests properly by aligning left elements to the left-most position" do
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(3, 5))

          expect(rendered_element_b.position).to eq(Position.new(0, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(3, 5))

          expect(rendered_element_c.position).to eq(Position.new(0, 0))
          expect(rendered_element_c.size).to eq(Dimension.new(3, 5))
        end

        it "still floats and positions elements correctly when nested" do
          # float
          expect(rendered_element_d.position).to eq(Position.new(0, 0))
          expect(rendered_element_d.size).to eq(Dimension.new(2, 5))

          # block gets placed beside the float
          expect(rendered_element_e.position).to eq(Position.new(2, 0))
          expect(rendered_element_e.size).to eq(Dimension.new(1, 5))
        end
      end
    end

    describe "normal flow - float right" do
      context "with a single element float right without a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :right}) }

        it "doesn't include the element in the render render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end

      context "with a single element float right without a height" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :right, width: 1}) }

        it "doesn't include the element in the render render_tree" do
          expect(render_tree.children.length).to eq(0)
        end
      end

      context "with a single element float right with a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){  Box.new(style: {width: 5, height: 1, display: :float, float: :right}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "includes the element at the right-most position minus its width for the current row" do
          expect(rendered_element_a.position).to eq(Position.new(5, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(5, 1))
        end
      end

      context "a float right element without a height that has a block child" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :right, width: 1}, children: [block_b]) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          expect(rendered_element_a.height).to eq(1)
        end
      end

      context "a float right element without a height that has multiple block children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :right, width: 10}, children: [block_b, block_c]) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }
        let(:block_c){ Box.new(style: {width: 5, height: 4, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          expect(rendered_element_a.height).to eq(5)
        end
      end

      context "a float right element without a height that has inline children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :right, width: 5}, children: [inline_b]) }
        let(:inline_b){ Box.new(content: "ABCDEFGHIJK", style: {display: :inline}) }

        let(:rendered_element_a){ first_rendered(float_a) }

        it "gets its height from its children" do
          # Line 1: ABCDE, Line 2: FGHIJ, Line 3: K
          expect(rendered_element_a.height).to eq(3)
        end
      end

      context "with a float right followed by a block element" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, block_b] }
        let(:float_a){ Box.new(style: {width: 5, height: 1, display: :float, float: :right}) }
        let(:block_b){ Box.new(style: {width: 5, height: 1, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(block_b) }

        context "and they both fit on the same line" do
          it "puts the block element before the float right element" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(5, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # block
            expect(rendered_element_b.position).to eq(Position.new(0, 0))
            expect(rendered_element_b.size).to eq(Dimension.new(5, 1))
          end
        end

        context "and they do not fit on the same line" do
          before do
            block_b.width = 6
          end

          it "puts the block element on the next line" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(5, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # block
            expect(rendered_element_b.position).to eq(Position.new(0, 1))
            expect(rendered_element_b.size).to eq(Dimension.new(6, 1))
          end
        end
      end

      context "with a float right followed by an inline element" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, inline_b] }
        let(:float_a){ Box.new(style: {width: 5, height: 1, display: :float, float: :right}) }
        let(:inline_b){ Box.new(content: "ABCD", style: {height: 1, display: :inline}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(inline_b) }

        context "and they both fit on the same line" do
          it "puts it after the inline elements on the same line" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(5, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # inline
            expect(rendered_element_b.position).to eq(Position.new(0, 0))
            expect(rendered_element_b.size).to eq(Dimension.new(4, 1))
          end
        end

        context "and they do not fit on the same line" do
          before do
            inline_b.content = "ABCDEFGHIJ"
          end

          let(:rendered_elements_b){ all_rendered(inline_b) }

          it "puts wraps the text onto the next line" do
            # float
            expect(rendered_element_a.position).to eq(Position.new(5, 0))
            expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

            # inline
            expect(rendered_elements_b[0].position).to eq(Position.new(0, 0))
            expect(rendered_elements_b[0].size).to eq(Dimension.new(5, 1))

            expect(rendered_elements_b[1].position).to eq(Position.new(0, 1))
            expect(rendered_elements_b[1].size).to eq(Dimension.new(5, 1))
          end
        end
      end

      context "with multiple elements floated left" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, float_b, float_c, float_d] }
        let(:float_a){ Box.new(style: {width: 3, height: 1, display: :float, float: :right}) }
        let(:float_b){ Box.new(style: {width: 3, height: 1, display: :float, float: :right}) }
        let(:float_c){ Box.new(style: {width: 3, height: 1, display: :float, float: :right}) }
        let(:float_d){ Box.new(style: {width: 3, height: 1, display: :float, float: :right}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(float_b) }
        let(:rendered_element_c){ first_rendered(float_c) }
        let(:rendered_element_d){ first_rendered(float_d) }

        it "places them horizontally next to each other" do
          expect(rendered_element_a.position).to eq(Position.new(7, 0))
          expect(rendered_element_b.position).to eq(Position.new(4, 0))
          expect(rendered_element_c.position).to eq(Position.new(1, 0))
        end

        it "wraps floats that don't fit on the current line to the next line" do
          expect(rendered_element_d.position).to eq(Position.new(7, 1))
        end
      end

      context "with a float right element that is taller than a single line" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, block_b, block_c] }
        let(:float_a){ Box.new(style: {width: 3, height: 5, display: :float, float: :right}) }
        let(:block_b){ Box.new(style: {width: 3, height: 2, display: :block}) }
        let(:block_c){ Box.new(style: {width: 3, height: 2, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(block_b) }
        let(:rendered_element_c){ first_rendered(block_c) }

        it "spans multiple lines" do
          expect(rendered_element_a.position).to eq(Position.new(7, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(3, 5))
        end

        it "positions block elements next to the float on all lines" do
          expect(rendered_element_b.position).to eq(Position.new(0, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(3, 2))

          expect(rendered_element_c.position).to eq(Position.new(0, 2))
          expect(rendered_element_c.size).to eq(Dimension.new(3, 2))
        end
      end

      context "nested floats" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {width: 7, height: 5, display: :float, float: :right}, children: [
          float_b
        ])}
        let(:float_b){ Box.new(style: {width: 6, height: 5, display: :float, float: :right}, children: [
          float_c
        ])}
        let(:float_c){ Box.new(style: {width: 5, height: 5, display: :float, float: :right}, children: [
          float_d,
          block_e
        ])}
        let(:float_d){ Box.new(style: {width: 2, height: 5, display: :float, float: :right}) }
        let(:block_e){ Box.new(style: {width: 1, height: 5, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(float_b, parent: rendered_element_a) }
        let(:rendered_element_c){ first_rendered(float_c, parent: rendered_element_b) }
        let(:rendered_element_d){ first_rendered(float_d, parent: rendered_element_c) }
        let(:rendered_element_e){ first_rendered(block_e, parent: rendered_element_c) }

        it "nests properly by aligning right elements to the right-most position" do
          expect(rendered_element_a.position).to eq(Position.new(3, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(7, 5))

          expect(rendered_element_b.position).to eq(Position.new(1, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(6, 5))

          expect(rendered_element_c.position).to eq(Position.new(1, 0))
          expect(rendered_element_c.size).to eq(Dimension.new(5, 5))
        end

        it "still floats and positions elements correctly when nested" do
          # float
          expect(rendered_element_d.position).to eq(Position.new(3, 0))
          expect(rendered_element_d.size).to eq(Dimension.new(2, 5))

          # block gets placed beside the float
          expect(rendered_element_e.position).to eq(Position.new(0, 0))
          expect(rendered_element_e.size).to eq(Dimension.new(1, 5))
        end
      end

    end

  end
end
