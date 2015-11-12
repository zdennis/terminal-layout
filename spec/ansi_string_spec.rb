require 'spec_helper'
require 'term/ansicolor'

describe 'ANSIString' do
  include Term::ANSIColor

  describe "constructing" do
    it "can be constructed with a String" do
      ansi_string = ANSIString.new "this is a string"
      expect(ansi_string).to be
    end

    it "can be constructed with a String containing ANSI escape sequences" do
      ansi_string = ANSIString.new "this #{blue('is')} a string"
      expect(ansi_string).to be
    end
  end

  describe "redundant ANSI sequences" do
    it "strips out redundant ANSI sequences that are immediately next to each other" do
      ansi_string = ANSIString.new "this is\e[31m\e[31m a string"
      expect(ansi_string.to_s).to eq "this is\e[31m a string"
    end

    it "strips out redundant ANSI sequences that are not immediately next to each other" do
      ansi_string = ANSIString.new "this \e[31m a\e[31m string"
      expect(ansi_string.to_s).to eq "this \e[31m a string"
    end

    it "does not strip out ANSI sequences that differ" do
      ansi_string = ANSIString.new "this \e[31m a\e[32m string"
      expect(ansi_string.to_s).to eq "this \e[31m a\e[32m string"
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

  describe "#<<" do
    it "appends a String onto the end of the current ANSIString" do
      ansi_string =  ANSIString.new "a"
      ansi_string << "b"
      expect(ansi_string).to eq ANSIString.new("ab")
    end

    it "appends an ANSIString onto the end of the current ANSIString" do
      ansi_string =  ANSIString.new "a"
      ansi_string << ANSIString.new(blue("b"))
      expect(ansi_string).to eq ANSIString.new("a#{blue('b')}")
    end
  end

  describe "#length" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns the length string without ANSI escape sequences" do
      expect(ansi_string.length).to eq string.length
    end
  end

  describe "#index" do
    it "returns the index of the first occurrence of the given substring" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.index("b")).to eq 12

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.index("blu")).to eq 8

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.index("yellow")).to eq 25
    end

    it "returns the index starting on or after an optional start position" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.index("t", 0)).to eq 0

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.index("is", 3)).to eq 5
      expect(ansi_string.index("bl", 7)).to eq 8
      expect(ansi_string.index("bl", 9)).to eq nil

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.index("yel", 5)).to eq 25
      expect(ansi_string.index("yel", 25)).to eq 25
      expect(ansi_string.index("yel", 26)).to eq nil
    end

    it "returns the index of the first occurrence of the given regular expression" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.index(/b/)).to eq 12

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.index(/blu/)).to eq 8

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.index(/y.ll.w/)).to eq 25
    end
  end

  describe "#rindex" do
    it "returns the index of the last occurrence of the given substring" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.rindex("i")).to eq 5

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.rindex("blu")).to eq 8

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.rindex("yellow")).to eq 25
    end

    it "returns the index of the match on or after an optional stop position" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.rindex("t", 0)).to eq 0
      expect(ansi_string.rindex("is", 3)).to eq 2
      expect(ansi_string.rindex("bl", 12)).to eq 12

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.rindex("is", 0)).to eq nil
      expect(ansi_string.rindex("is", 3)).to eq 2
      expect(ansi_string.rindex("bl", 8)).to eq 8
      expect(ansi_string.rindex("bl", 12)).to eq 8

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.rindex("yel", 5)).to eq nil
      expect(ansi_string.rindex("yel", 25)).to eq 25
      expect(ansi_string.rindex("yel", 26)).to eq 25
    end

    it "returns the index of the last occurrence of the given regular expression" do
      ansi_string = ANSIString.new("this is not blue")
      expect(ansi_string.rindex(/b/)).to eq 12

      ansi_string = ANSIString.new("this is #{blue('blue')}")
      expect(ansi_string.rindex(/blu/)).to eq 8

      ansi_string = ANSIString.new("this is #{blue('blue')} and this is #{yellow('yellow')}")
      expect(ansi_string.rindex(/y.ll.w/)).to eq 25
    end
  end

  describe "#[]" do
    subject(:ansi_string){ ANSIString.new "#{blue_string}ABC#{yellow_string}" }
    let(:blue_string){ blue("this is blue") }
    let(:yellow_string){ yellow("this is yellow") }

    it "returns the full substring with the appropriate ANSI start and end sequence" do
      expect(ansi_string[0...12]).to eq ANSIString.new(blue("this is blue"))
      expect(ansi_string[15..-1]).to eq ANSIString.new(yellow("this is yellow"))
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

      it "combines when the ANSI sequences are the same" do
        ansi_string[13..15] = ANSIString.new green("ed")
        expect(ansi_string).to eq ANSIString.new(green("CircleCI passed"))
      end

      it "doesn't combine when the ANSI sequences are different" do
        ansi_string[13..15] = ANSIString.new red("ed")
        expect(ansi_string).to eq ANSIString.new(green("CircleCI pass") + red("ed"))
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

    context "replacing a substring that goes across ANSI sequence boundaries" do
      subject(:ansi_string){ ANSIString.new "this#{blue('that')}" }

      it "successfully moves the boundaries" do
        ansi_string[3..4] = yellow("SORRY")
        expect(ansi_string).to eq ANSIString.new("thi#{yellow('SORRY')}#{blue('hat')}")
      end
    end

    it "raises an error out of index" do
      expect {
        ansi_string[14..15] = string
      }.to raise_error(RangeError, "14..15 out of range")
    end

    context "replacing a substring that comes entirely after an ANSI sequence" do
      subject(:ansi_string){ ANSIString.new "this #{blue('is')} your television screen." }

      it "places the substring in the correct location" do
        ansi_string[14..15] = "YO YO"
        expect(ansi_string).to eq ANSIString.new "this #{blue('is')} your tYO YOevision screen."
      end
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
