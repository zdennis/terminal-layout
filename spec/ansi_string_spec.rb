require 'spec_helper'
require 'term/ansicolor'

describe 'ANSIString' do
  include Term::ANSIColor

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

    context "and the range is around the ANSI sequence location in the string" do
      it "returns the string with the ANSI sequences within it intact" do
        ansi_string = ANSIString.new "abc#{green('def')}ghi"
        expect(ansi_string[0..-1]).to eq "abc#{green('def')}ghi"
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
  end

  describe "#to_s" do
    subject(:ansi_string){ ANSIString.new blue(string) }
    let(:string){ "this is blue" }

    it "returns the ANSI capable string" do
      expect(ansi_string.to_s).to eq blue(string)
    end
  end
end
