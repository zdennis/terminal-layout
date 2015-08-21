require 'spec_helper'
require 'pry'

def print_tree(tree, indent=0)
  tree.each do |box|
    print " " * indent
    puts box
    print_tree box.children, indent + 2
  end
end

module TerminalLayout

  describe "Laying things out" do
    after(:each) do |example|
      if example.exception
        puts
        puts " #{example.location} #{example.description}"
        print_tree tree
      end
    end

    describe "normal block flow - vertical stacking" do
      subject(:tree){ RenderTree.new(view).layout }
      let(:view){ Box.new(style: style, children: children) }
      let(:style){ raise(NotImplementedError, "Must provide :children") }
      let(:children){ raise(NotImplementedError, "Must provide :children") }

      context "with one block child" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_box_a] }
        let(:block_box_a){ Box.new(style: {display: :block, height: 1}) }

        it "positions the box at (0,0) with the same width as its containing box" do
          expect(tree.first.position).to eq(Position.new(0, 0))
          expect(tree.first.size).to eq(Dimension.new(10, 1))
        end
      end

      context "with multiple block children" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_box_a, block_box_b] }
        let(:block_box_a){ Box.new(style: {display: :block, height: 1}) }
        let(:block_box_b){ Box.new(style: {display: :block, height: 1}) }

        it "stacks the boxes vertically with the widths matching the containing box" do
          expect(tree.length).to eq(2)

          expect(tree.first.position).to eq(Position.new(0, 0))
          expect(tree.first.size).to eq(Dimension.new(10, 1))

          expect(tree.last.position).to eq(Position.new(0, 1))
          expect(tree.last.size).to eq(Dimension.new(10, 1))
        end
      end

      context "with a block child that has 0 height" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_box_0_height] }
        let(:block_box_0_height){ Box.new(style: {display: :block, height: 0}) }

        it "doesn't include it in the layout tree" do
          expect(tree.length).to eq(0)
        end
      end

      context "with a block child that has 0 width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [block_box_0_width] }
        let(:block_box_0_width){ Box.new(style: {display: :block, width: 0}) }

        it "doesn't include it in the layout tree" do
          expect(tree.length).to eq(0)
        end
      end
    end

    describe "normal flow - inline elements" do
      subject(:tree){ RenderTree.new(view).layout }
      let(:view){ Box.new(style: style, children: children) }
      let(:style){ raise(NotImplementedError, "Must provide :children") }
      let(:children){ raise(NotImplementedError, "Must provide :children") }

      context "with multiple inline children that fit within the width of the parent" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [inline_box_a, inline_box_b] }
        let(:inline_box_a){ Box.new(content:"ABC", style: {display: :inline}) }
        let(:inline_box_b){ Box.new(content:"DEFGHIJ", style: {display: :inline}) }

        it "horizontally lays out the two boxes with the width matching their respective content's length" do
          expect(tree.length).to eq(2)

          expect(tree.first.content).to eq("ABC")
          expect(tree.first.position).to eq(Position.new(0, 0))
          expect(tree.first.size).to eq(Dimension.new(3, 1))

          expect(tree.last.content).to eq("DEFGHIJ")
          expect(tree.last.position).to eq(Position.new(3, 0))
          expect(tree.last.size).to eq(Dimension.new(7, 1))
        end
      end

      context "with multiple inline children that do not fit within the width of the parent" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [inline_box_a, inline_box_b] }
        let(:inline_box_a){ Box.new(content:"ABCDEFG", style: {display: :inline}) }
        let(:inline_box_b){ Box.new(content:"HIJKLMNO", style: {display: :inline}) }

        it "horizontally lays out the two boxes wrapping lines as needed" do
          expect(tree.length).to eq(3)

          # row 1
          expect(tree[0].content).to eq("ABCDEFG")
          expect(tree[0].position).to eq(Position.new(0, 0))
          expect(tree[0].size).to eq(Dimension.new(7, 1))

          expect(tree[1].content).to eq("HIJ")
          expect(tree[1].position).to eq(Position.new(7, 0))
          expect(tree[1].size).to eq(Dimension.new(3, 1))

          # row 2
          expect(tree[2].content).to eq("KLMNO")
          expect(tree[2].position).to eq(Position.new(0, 1))
          expect(tree[2].size).to eq(Dimension.new(5, 1))
        end
      end
    end


    describe "normal float - float left" do
      subject(:tree){ RenderTree.new(view).layout }
      let(:view){ Box.new(style: style, children: children) }
      let(:style){ raise(NotImplementedError, "Must provide :children") }
      let(:children){ raise(NotImplementedError, "Must provide :children") }

      context "with a single element float left without a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left}) }

        it "doesn't include the element in the render tree" do
          expect(tree.length).to eq(0)
        end
      end

      context "with a single element float left without a height" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {display: :float, float: :left, width: 1}) }

        it "doesn't include the element in the render tree" do
          expect(tree.length).to eq(0)
        end
      end

      context "with a single element float left with a width" do
        let(:style){ {width:10, height: 10} }
        let(:children){ [float_a] }
        let(:float_a){ Box.new(style: {width: 5, height: 1, display: :float, float: :left}) }

        it "includes the element at the left-most position for the current row" do
          expect(tree.first.position).to eq(Position.new(0, 0))
          expect(tree.first.size).to eq(Dimension.new(5, 1))
        end

        it "puts it before block elements on the same line"

        it "puts it before inline elements on the same line"
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
