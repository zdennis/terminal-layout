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

    it "can be constructed with UTF-8 characters" do;
      expect do
        ansi_string = ANSIString.new "this #{blue('ƒ')} a string"
        expect(ansi_string).to be
      end.to_not raise_error
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

  describe "#each_byte" do
    let(:blue_ansi_string){ ANSIString.new blue_string }
    let(:blue_string){ blue("this is blue") }

    it "iterates over each character ignoring ANSI sequences" do
      expected = "this is blue"
      actual = ""
      blue_ansi_string.each_byte { |ch| actual << ch }
      expect(actual).to eq(expected)
    end
  end

  describe "#each_char" do
    let(:blue_ansi_string){ ANSIString.new blue_string }
    let(:blue_string){ blue("this is blue") }

    it "iterates over each character ignoring ANSI sequences" do
      expected = "this is blue"
      actual = ""
      blue_ansi_string.each_char { |ch| actual << ch }
      expect(actual).to eq(expected)
    end
  end

  describe "#<<" do
    it "appends a String onto the end of the current ANSIString" do
      ansi_string = ANSIString.new ""
      ansi_string << "a"
      expect(ansi_string).to eq ANSIString.new("a")

      ansi_string << "b"
      expect(ansi_string).to eq ANSIString.new("ab")

      ansi_string << "cd"
      expect(ansi_string).to eq ANSIString.new("abcd")
    end

    it "appends an ANSIString onto the end of the current ANSIString" do
      ansi_string = ANSIString.new ""
      ansi_string << ANSIString.new(blue("a"))
      expect(ansi_string).to eq ANSIString.new("#{blue('a')}")

      ansi_string << ANSIString.new(yellow("b"))
      expect(ansi_string).to eq ANSIString.new("#{blue('a')}#{yellow('b')}")

      ansi_string << ANSIString.new(red("cd"))
      expect(ansi_string).to eq ANSIString.new("#{blue('a')}#{yellow('b')}#{red('cd')}")
    end
  end

  describe "#insert (see Ruby's String#insert for intent)" do
    it "insert a string into the ANSIString" do
      ansi_string = ANSIString.new "az"
      ansi_string.insert 1, "thru"
      expect(ansi_string).to eq ANSIString.new("athruz")

      ansi_string.insert 0, "_"
      expect(ansi_string).to eq ANSIString.new("_athruz")

      ansi_string.insert ansi_string.length, "_"
      expect(ansi_string).to eq ANSIString.new("_athruz_")
    end

    it "insert an ANSIString into an ANSIString" do
      ansi_string = ANSIString.new blue("az")
      ansi_string.insert 1, yellow("thru")
      expect(ansi_string).to eq ANSIString.new("\e[34ma\e[33mthru\e[0mz\e[0m")
    end

    it "inserts from the end with a negative position" do
      ansi_string = ANSIString.new blue("az")
      ansi_string.insert -2, yellow("thru")
      expect(ansi_string).to eq ANSIString.new("\e[34ma\e[33mthru\e[0mz\e[0m")
    end
  end

  describe "#length" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns the length string without ANSI escape sequences" do
      expect(ansi_string.length).to eq string.length
    end
  end

  describe "#empty?" do
    it "returns true when empty" do
      expect(ANSIString.new("").empty?).to be(true)
    end

    it "returns true when it only contains ANSI sequences" do
      expect(ANSIString.new(blue("")).empty?).to be(true)
    end

    it "returns false when there are non-ANSI characters" do
      expect(ANSIString.new("a").empty?).to be(false)
      expect(ANSIString.new(blue("a")).empty?).to be(false)
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

    it "returns the correct substring when location of an ANSI sequence comes before the end of the request" do
      s = ANSIString.new("ABC \e[7mGemfile.lock\e[0m LICENSE.txt  README.md")
      expect(s[4...28]).to eq ANSIString.new("\e[7mGemfile.lock\e[0m LICENSE.txt")
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

    it "returns nil when the given range is beyond the length of the string" do
      ansi_string = ANSIString.new "abc"
      expect(ansi_string[4]).to be nil
    end
  end

  describe "#[]=" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns a new ANSIString with the string at the given index replaced with the new string" do
      ansi_string[1] = "Z"
      expect(ansi_string).to eq ANSIString.new(blue("tZis is blue"))
    end

    it "returns a new ANSIString with the string at the given range replaced with the new string" do
      ansi_string[1..2] = "ZYX"
      expect(ansi_string).to eq ANSIString.new(blue("tZYXs is blue"))
    end

    it "supports replacing with negative indexes at the front of the string" do
      ansi_string[0..-1] = "abc"
      expect(ansi_string).to eq ANSIString.new(blue("abc"))
    end

    it "supports replacing with negative indexes in the middle of the string" do
      ansi_string = ANSIString.new(blue("abc"))
      ansi_string[1..-2] = red("*")

      # Do not preserve reset sequences (e.g. "\e[0m") when inserting/replacing.
      # So no \e[0m before the replacement '*'
      expect(ansi_string).to eq ANSIString.new("\e[34ma\e[31m*\e[0mc\e[0m")
    end

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

      it "moves the boundaries when using positive indexes and a regular String replacement" do
        ansi_string[3..4] = yellow("SORRY")
        expect(ansi_string).to eq ANSIString.new("thi#{yellow('SORRY')}#{blue('hat')}")
      end

      it "moves the boundaries when using positive indexes and an ANSIString replacement" do
        ansi_string[3..4] = yellow("SORRY")
        expect(ansi_string).to eq ANSIString.new("thi#{yellow('SORRY')}#{blue('hat')}")
      end

      it "moves the boundaries when using negatives indexes and a regular String replacement" do
        ansi_string[-5..4] = "SORRY"
        expect(ansi_string).to eq ANSIString.new("thiSORRY#{blue('hat')}")
      end

      it "moves the boundaries when using negatives indexes and an ANSIString replacement" do
        ansi_string[-5..4] = yellow("SORRY")
        expect(ansi_string).to eq ANSIString.new("thi#{yellow('SORRY')}#{blue('hat')}")
      end
    end

    context "clearing the string" do
      subject(:ansi_string){ ANSIString.new "this\nthat" }

      it "clears the string" do
        ansi_string[0..-1] = ""
        expect(ansi_string).to eq ANSIString.new("")
      end
    end

    context "expanding a string" do
      subject(:ansi_string){ ANSIString.new "" }

      it "expands the string" do
        ansi_string[0..-1] = ANSIString.new(blue("HI"))
        expect(ansi_string).to eq ANSIString.new(blue("HI"))
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

  describe "<=>" do
    let(:string_1){ ANSIString.new blue("abc") }
    let(:string_2){ ANSIString.new blue("def") }

    it "behaves the same as a normal string" do
      expect(string_1 <=> string_2).to eq(-1)
      expect(string_1 <=> string_1).to eq(0)
      expect(string_2 <=> string_1).to eq(1)
    end
  end

  describe "#match" do
    it "matches on a string pattren" do
      string = "apples are bananas are they not?"
      ansi_string = ANSIString.new("app#{red('les are bananas')} are they not?")
      expect(ansi_string.match("are")).to eq(string.match("are"))
    end

    it "matches on a regex pattren" do
      string = "apples are bananas are they not?"
      ansi_string = ANSIString.new("app#{red('les are bananas')} are they not?")
      expect(ansi_string.match(/are/)).to eq(string.match(/are/))
    end
  end

  describe "#=~" do
    it "matches on a regex pattren" do
      string = "apples are bananas are they not?"
      ansi_string = ANSIString.new("app#{red('les are bananas')} are they not?")
      expect(ansi_string =~ /are/).to eq(string =~ /are/)
    end
  end

  describe "#scan" do
    it "scans without capture groups" do
      string = "567"
      ansi_string = ANSIString.new("1234#{red('5678')}90")
      expect(ansi_string.scan(/.{2}/)).to eq([
        ANSIString.new("12"),
        ANSIString.new("34"),
        ANSIString.new("#{red('56')}"),
        ANSIString.new("#{red('78')}"),
        ANSIString.new("90")
      ])
    end

    it "scans with capture groups" do
      string = "567"
      ansi_string = ANSIString.new("1234#{red('5678')}90")
      expect(ansi_string.scan(/(.)./)).to eq([
        [ANSIString.new("1")],
        [ANSIString.new("3")],
        [ANSIString.new("#{red('5')}")],
        [ANSIString.new("#{red('7')}")],
        [ANSIString.new("9")]
      ])
    end
  end

  describe "#replace" do
    it "replaces the contents of the current string with the new string" do
      ansi_string = ANSIString.new("abc")
      original_object_id = ansi_string.object_id
      expect(ansi_string.replace("def")).to eq ANSIString.new("def")
      expect(ansi_string.object_id).to eq(original_object_id)
    end
  end

  describe "#reverse" do
    it "reverses the string" do
      ansi_string = ANSIString.new("abc")
      expect(ansi_string.reverse).to eq ANSIString.new("cba")
    end

    it "reverses the string with ANSI sequences" do
      ansi_string = ANSIString.new("a#{blue('b')}#{yellow('c')}")
      expect(ansi_string.reverse).to eq ANSIString.new("#{yellow('c')}#{blue('b')}a")
    end
  end

  describe "#slice" do
    it "returns a substring of one character given a numeric index" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(0)).to eq ANSIString.new("a")
      expect(ansi_string.slice(1)).to eq ANSIString.new(blue("b"))
      expect(ansi_string.slice(2)).to eq ANSIString.new("c")
    end

    it "returns a substring of characters of N length given a start index and max length N" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(0, 0)).to eq ANSIString.new("")
      expect(ansi_string.slice(0, 2)).to eq ANSIString.new("a#{blue('b')}")
      expect(ansi_string.slice(1, 2)).to eq ANSIString.new("#{blue('b')}c")

      # length is over, doesn't blow up
      expect(ansi_string.slice(1, 3)).to eq ANSIString.new("#{blue('b')}c")
    end

    it "returns a substring of characters using a range as delimiters" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(0..1)).to eq ANSIString.new("a#{blue('b')}")
      expect(ansi_string.slice(0...2)).to eq ANSIString.new("a#{blue('b')}")

      # length is over, doesn't blow up
      expect(ansi_string.slice(1..3)).to eq ANSIString.new("#{blue('b')}c")
    end

    it "returns a substring of characters matching the given regex" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(/b/)).to eq ANSIString.new("#{blue('b')}")
      expect(ansi_string.slice(/(b)c/)).to eq ANSIString.new("#{blue('b')}c")

      # length is over, doesn't blow up
      expect(ansi_string.slice(/.*/)).to eq ANSIString.new("a#{blue('b')}c")
    end

    it "returns a substring for the capture group matching the given regex and capture group index" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(/((a)(b)(c))/, 1)).to eq ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice(/((a)(b)(c))/, 2)).to eq ANSIString.new("a")
      expect(ansi_string.slice(/((a)(b)(c))/, 3)).to eq ANSIString.new("#{blue('b')}")
      expect(ansi_string.slice(/((a)(b)(c))/, 4)).to eq ANSIString.new("c")
    end

    it "returns the substring when a given string is found" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice("bc")).to eq(ANSIString.new("#{blue('b')}c"))
    end

    it "returns nil when no matches are found" do
      ansi_string = ANSIString.new("a#{blue('b')}c")
      expect(ansi_string.slice("zzz")).to be nil
      expect(ansi_string.slice(/zzz/)).to be nil
      expect(ansi_string.slice(99)).to be nil
      expect(ansi_string.slice(99, 100)).to be nil
      expect(ansi_string.slice(99..100)).to be nil
    end
  end

  describe "#split" do
    it "splits on the given string pattern" do
      ansi_string = ANSIString.new("apples are #{red('red')}. bananas are #{blue('blue')}. cats are #{yellow('yellow')}.")
      expect(ansi_string.split(". ")).to eq([
        ANSIString.new("apples are #{red('red')}"),
        ANSIString.new("bananas are #{blue('blue')}"),
        ANSIString.new("cats are #{yellow('yellow')}.")
      ])
    end

    it "splits on the given regex pattern" do
      ansi_string = ANSIString.new("apples are #{red('red')}. bananas are #{blue('blue')}. cats are #{yellow('yellow')}.")
      expect(ansi_string.split(/\.\s?/)).to eq([
        ANSIString.new("apples are #{red('red')}"),
        ANSIString.new("bananas are #{blue('blue')}"),
        ANSIString.new("cats are #{yellow('yellow')}")
      ])
    end

    it "limits how many times it splits with a secondary limit argument" do
      ansi_string = ANSIString.new("apples are #{red('red')}. bananas are #{blue('blue')}. cats are #{yellow('yellow')}.")
      expect(ansi_string.split(/\.\s?/, 2)).to eq([
        ANSIString.new("apples are #{red('red')}"),
        ANSIString.new("bananas are #{blue('blue')}. cats are #{yellow('yellow')}.")
      ])
    end
  end

  describe "#strip" do
    it 'returns a copy of the string with leading and trailing whitespace removed' do
      ansi_string = ANSIString.new " this is his #{blue('pig')} "
      expect(ansi_string.strip).to eq ANSIString.new "this is his #{blue('pig')}"
      expect(ansi_string).to eq ANSIString.new " this is his #{blue('pig')} "
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
