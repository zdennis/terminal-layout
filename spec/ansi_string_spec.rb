require 'spec_helper'
require 'term/ansicolor'

describe 'ANSIString' do
  include Term::ANSIColor

  describe "redundant ANSI sequences" do
    it "removes repetitive nearby neighbor sequences" do
      ansi_string = ANSIString.new("\e[31m\e[31mHI\e[0m\e[0m")
      expect(ansi_string.raw).to eq("\e[31mHI\e[0m")

      ansi_string = ANSIString.new("\e[31m\e[31m\e[31mHI\e[0m\e[0m")
      expect(ansi_string.raw).to eq("\e[31mHI\e[0m")

      ansi_string = ANSIString.new("\e[31m\e[32m\e[32mHI\e[0m\e[0m")
      expect(ansi_string.raw).to eq("\e[31m\e[32mHI\e[0m")
    end

    it "removes repetitive adjacent sequences" do
      ansi_string = ANSIString.new(blue("HI") + blue("BY") + blue("E"))
      expect(ansi_string.raw).to eq(blue("HIBYE"))
    end
  end

  describe "#+ combining strings" do
    let(:blue_ansi_string){ ANSIString.new blue_string }
    let(:yellow_ansi_string){ ANSIString.new yellow_string }
    let(:blue_string){ blue("this is blue") }
    let(:yellow_string){ yellow("this is yellow") }

    it "returns a new string when combining two ANSIStrings" do
      expect(blue_ansi_string + yellow_ansi_string).to eq ANSIString.new(blue_string + yellow_string)
    end

    it "returns a new string when combining a ANIString with a String" do
      expect(blue_ansi_string + yellow_string).to eq ANSIString.new(blue_string + yellow_string)
    end

  end

  describe "#length" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns the length string without ANSI escape sequences" do
      expect(ansi_string.length).to eq string.length
    end
  end

  describe "#[]" do
    subject(:ansi_string){ ANSIString.new "#{blue_string}ABC#{yellow_string}" }
    let(:blue_string){ blue("this is blue") }
    let(:yellow_string){ yellow("this is yellow") }

    it "returns the full substring with the appropriate ANSI start and end sequence" do
      expect(ansi_string[0...12]).to eq blue("this is blue")
      expect(ansi_string[15..-1]).to eq yellow("this is yellow")
    end

    it "returns a partial substring with the appropriate ANSI start sequence and provides an end sequence" do
      expect(ansi_string[0..1]).to eq blue("th")
      expect(ansi_string[17..-5]).to eq yellow("is is ye")
    end

    it "returns text that is not ANSI escaped" do
      expect(ansi_string[12..14]).to eq "ABC"
    end

    it "returns up to the end" do
      expect(ansi_string[-2..-1]).to eq yellow("ow")
    end

    context "and the range is around the ANSI sequence location in the string" do
      it "returns the string with the ANSI sequences within it intact" do
        ansi_string = ANSIString.new "abc#{green('def')}ghi"
        expect(ansi_string[0..-1]).to eq "abc#{green('def')}ghi"
      end

      it "returns the string with the ANSI sequences within it intact" do
        ansi_string = ANSIString.new "abc#{green('def')}ghi"
        expect(ansi_string[0..2]).to eq "abc"
      end

    end
  end

  describe "#[]=" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "preserves coloring when part of the text with a String" do
      ansi_string[0..3] = "that"
      expect(ansi_string).to eq ANSIString.new(blue("that is blue"))
    end

    it "preserves coloring when replacing all of the text with a String" do
      ansi_string[0..11] = "foobar"
      expect(ansi_string).to eq ANSIString.new(blue("foobar"))
    end

    it "preserves coloring when part of the text with a String and we're not starting at an index of 0" do
      ansi_string[5..6] = "ain't"
      expect(ansi_string).to eq ANSIString.new(blue("this ain't blue"))
    end

    context "appending a string to the very end" do
      subject(:ansi_string){ ANSIString.new green("CircleCI pass") }
      let(:string){ ANSIString.new green("ed") }

      it "works" do
        ansi_string[13..15] = string
        expect(ansi_string).to eq ANSIString.new(green("CircleCI passed"))
      end
    end

    context "replacing on newline boundaries" do
      subject(:ansi_string){ ANSIString.new "this\nthat" }

      it "keeps the new line intact" do
        ansi_string[2...4] = "IS"
        expect(ansi_string).to eq ANSIString.new("thIS\nthat")
      end
    end

    context "replacing the same location twice" do
      subject(:ansi_string){ ANSIString.new "this\nthat" }

      it "keeps the new line intact" do
        ansi_string[2...4] = blue("IS")
        ansi_string[2...4] = blue("IS")
        expect(ansi_string).to eq ANSIString.new("th#{blue('IS')}\nthat")
      end
    end

    it "raises an error out of index" do
      expect {
        ansi_string[14..15] = string
      }.to raise_error(RangeError, "14..15 out of range")
    end
  end

  describe "#dup" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns a dup'd version of itself" do
      duped = ansi_string.dup
      expect(duped).to be_kind_of(ANSIString)
      expect(duped.raw).to eq(ansi_string.raw)
    end
  end

  describe "#lines" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this\nis\nblue" }

    it "returns lines" do
      expect(ansi_string.lines).to eq [
        ANSIString.new(blue("this\n")),
        ANSIString.new(blue("is\n")),
        ANSIString.new(blue("blue"))
      ]
    end

    it "returns lines" do
      ansi_string = ANSIString.new blue("abc") + "\n" + red("d\nef") + "hi\n" + yellow("foo")
      expect(ansi_string.lines).to eq [
        ANSIString.new(blue("abc") + "\n"),
        ANSIString.new(red("d\n")),
        ANSIString.new(red("ef") + "hi\n"),
        ANSIString.new(yellow("foo"))
      ]
    end

  end

  describe "#==" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns true when comparing against itself" do
      expect(ansi_string).to eq ansi_string
    end

    it "returns true when comparing against another ANSIString with the same contents" do
      expect(ansi_string).to eq ANSIString.new(blue(string))
    end

    it "returns false when comparing against another ANSIString with differnent contents" do
      expect(ansi_string).to_not eq ANSIString.new(blue("other stuff"))
    end

    it "returns true when comparing against a String with the same raw contents" do
      expect(ansi_string).to eq blue(string)
    end

    it "returns true when comparing against a String that doesn't match its raw contents" do
      expect(ansi_string).to_not eq "asfsd"
    end
  end

  describe "#sub" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns an ANSIString" do
      expect(ansi_string.sub(/ is /, "")).to eq ANSIString.new(blue("thisblue"))
    end

    it "works across ansi sequences" do
      blue_string = blue("this is blue")
      yellow_string = yellow("this is yellow")
      non_colored_string = "hi there\nbye there"
      str = ANSIString.new(blue_string + yellow_string + non_colored_string + "  \n   \n   \n    ")
      expect(str.sub(/\s*\Z/m, "")).to eq ANSIString.new(blue_string + yellow_string + non_colored_string)
    end
  end

  describe "#gsub" do
    it "needs to be implemented"
  end

  describe "#to_s" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns the ANSI capable string" do
      expect(ansi_string.to_s).to eq blue(string)
    end
  end

  describe "#succ" do
    it "needs to be implemented"
  end
end
