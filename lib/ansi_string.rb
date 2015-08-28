class ANSIString
  attr_reader :raw

  def initialize(str)
    if str.is_a?(ANSIString)
      @raw = str.raw
    else
      @raw = str || ""
    end

    @without_ansi = ""
    @ansi_sequence_locations = @raw.enum_for(:scan, /(\033\[[0-9;]*m)(.*?)(\033\[[0-9;]*m)|(.*?)(?=\033\[[0-9;]*m|$)/).map do
      md = Regexp.last_match
      start_ansi_sequence, text, end_ansi_sequence, plaintext = md.captures
      {}.tap do |hsh|
        if plaintext
          hsh.merge!(
            begins_at: @without_ansi.length,
            ends_at: [@without_ansi.length + plaintext.length - 1, 0].max,
            length: plaintext.length,
            text: plaintext,
            start_ansi_sequence: nil,
            end_ansi_sequence: nil
          )
          @without_ansi << plaintext
        else
          hsh.merge!(
            begins_at: @without_ansi.length,
            ends_at: [@without_ansi.length + text.length - 1, 0].max,
            length: text.length,
            text: text,
            start_ansi_sequence: start_ansi_sequence,
            end_ansi_sequence: end_ansi_sequence
          )
          @without_ansi << text
        end
      end
    end
  end

  def [](range)
    text = @without_ansi[range]
    build_string_with_ansi_for(range.begin...(range.begin + text.length))
  end

  def length
    @without_ansi.length
  end

  def dup
    ANSIString.new(@raw.dup)
  end

  def sub(pattern, replacement)
    str = ""
    count = 0
    max_count = 1
    index = 0
    @without_ansi.enum_for(:scan, pattern).each do
      md = Regexp.last_match
      str << build_string_with_ansi_for(index...(index + md.begin(0)))
      index = md.end(0)
      break if (count += 1) == max_count
    end
    if index != @without_ansi.length
      str << build_string_with_ansi_for(index...@without_ansi.length)
    end
    str = str.gsub /(\033\[[0-9;]*m)(.+?)\033\[0m\1/, '\1\2'
    ANSIString.new(str)
  end

  def to_s
    @raw.dup
  end
  alias :to_str :to_s

  def ==(other)
    (other.class == self.class && other.raw == @raw) ||  (other.kind_of?(String) && other == @raw)
  end

  private

  def build_string_with_ansi_for(range)
    str = ""
    @ansi_sequence_locations.each do |location|
      # If the given range encompasses part of the location, then we want to
      # include the whole location
      if location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].join

      # If the location falls within the given range then  make sure we pull
      # out the bits that we want, and keep ANSI escape sequenece intact while
      # doing so.
      elsif (location[:begins_at] <= range.begin && location[:ends_at] >= range.end) || range.cover?(location[:ends_at])
        start_index = range.begin - location[:begins_at]
        end_index = range.end - location[:begins_at]
        str << [location[:start_ansi_sequence], location[:text][start_index...end_index], location[:end_ansi_sequence]].join
      end
    end
    str
  end

end
