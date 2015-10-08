class ANSIString
  attr_reader :raw

  def initialize(str)
    if str.is_a?(ANSIString)
      @raw = str.raw
    else
      @raw = str || ""
    end

    build_ansi_sequence_locations
  end

  def [](range)
    text = @without_ansi[range]
    str = build_string_with_ansi_for(range.begin...(range.begin + text.length))
    ANSIString.new str
  end

  def []=(range, replacement_str)
    text = @without_ansi[range]
    @raw = replace_in_string(range.begin...(range.begin + text.length), replacement_str)
    build_ansi_sequence_locations
    self
  end

  def length
    @without_ansi.length
  end

  def lines
    result = []
    current_string = ""
    @ansi_sequence_locations.map do |location|
      if location[:text] == "\n"
        result << ANSIString.new(current_string)
        current_string = ""
        next
      end

      location[:text].split("\n").each_with_index do |line, i|
        if i == 0
          current_string << [
            location[:start_ansi_sequence],
            line,
            location[:end_ansi_sequence]
          ].join
        else
          result << ANSIString.new(current_string)
          current_string = ""
          current_string << [
            location[:start_ansi_sequence],
            line,
            location[:end_ansi_sequence]
          ].join
        end
      end

      if location[:text].end_with?("\n")
        result << ANSIString.new(current_string)
        current_string = ""
        next
      end
    end
    result << ANSIString.new(current_string) if current_string.length > 0
    result
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
    nstr = str.gsub /(\033\[[0-9;]*m)(.+?)\033\[0m\1/, '\1\2'
    ANSIString.new(nstr)
  end

  def to_s
    @raw.dup
  end
  alias :to_str :to_s

  def ==(other)
    (other.class == self.class && other.raw == @raw) || (other.kind_of?(String) && other == @raw)
  end

  private

  def build_ansi_sequence_locations
    @without_ansi = ""
    @ansi_sequence_locations = @raw.enum_for(:scan, /(\033\[[0-9;]*m)(.*?)(\033\[[0-9;]*m)|(.*?)(?=(\033\[[0-9;]*m|\Z))/m ).map do
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
    end.compact.select{ |location| location[:text] != "" }
  end

  def replace_in_string(range, replacement_str)
    str = ""
    index = 0

    @ansi_sequence_locations.each do |location|
      # If the given range encompasses part of the location, then we want to
      # include the whole location
      if location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        str << [
          location[:start_ansi_sequence],
          replacement_str,
          location[:text][range.end..-1],
          location[:end_ansi_sequence]
        ].join
        index = range.end

      # If the location falls within the given range then  make sure we pull
      # out the bits that we want, and keep ANSI escape sequenece intact while
      # doing so.
      elsif (location[:begins_at] <= range.begin && location[:ends_at] >= range.end) || range.cover?(location[:ends_at])
        start_index = range.begin - location[:begins_at]
        end_index = range.end - location[:begins_at]
        str << [
          location[:start_ansi_sequence],
          location[:text][0...(range.begin - location[:begins_at])],
          replacement_str,
          location[:text][(range.end - location[:begins_at])..-1],
          location[:end_ansi_sequence]
        ].join
        index = range.end
      else
        str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].join
        index = location[:ends_at]
      end
    end
    str
  end

  def build_string_with_ansi_for(range)
    str = ""
    @ansi_sequence_locations.each do |location|
      # If the given range encompasses part of the location, then we want to
      # include the whole location
      if location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].join

      elsif location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        str << [location[:start_ansi_sequence], location[:text][0..(range.end - location[:begins_at])], location[:end_ansi_sequence]].join

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
