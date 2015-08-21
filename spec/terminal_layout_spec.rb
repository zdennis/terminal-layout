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
  return nil if tree.children.empty?
  tree.children.each do |node|
    return node if comparator_proc.call(node)
    find_first_in_tree node, comparator_proc
  end
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
    subject(:render_tree){ RenderTree.new(view).tap{ |rt| rt.layout } }
    let(:view){ Box.new(style: style, children: children) }
    let(:style){ raise(NotImplementedError, "Must provide :children") }
    let(:children){ raise(NotImplementedError, "Must provide :children") }

    def first_rendered(box)
      find_first_in_tree(render_tree, ->(node){ node.box == box })
    end

    def all_rendered(box)
      find_all_in_tree(render_tree, ->(node){ node.box == box })
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

    describe "normal float - float left" do
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
        let(:float_a){  Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }
        let(:block_b){  Box.new(style: {width: 5, height: 1, display: :block}) }

        let(:rendered_element_a){ first_rendered(float_a) }
        let(:rendered_element_b){ first_rendered(block_b) }

        it "puts the float left element before the block element on the same line" do
          # float
          expect(rendered_element_a.position).to eq(Position.new(0, 0))
          expect(rendered_element_a.size).to eq(Dimension.new(5, 1))

          # block
          expect(rendered_element_b.position).to eq(Position.new(5, 0))
          expect(rendered_element_b.size).to eq(Dimension.new(5, 1))
        end
      end

      context "with a float left followed by an block" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a, inline_b, block_c] }
        let(:float_a){  Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }

        it "puts it before inline elements on the same line" do


        end
      end

      context "with multiple elements floated left" do
        it "stacks them horizontally next to each other"

        it "puts them before block elements on the same line"

        it "puts them before inline elements on the same line"
      end

      context "with a floated element that is taller than a single line" do
        it "causes"
      end

    end

  end
end
