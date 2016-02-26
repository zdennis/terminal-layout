# encoding: UTF-8

require 'forwardable'

class ANSIString
  extend Forwardable
  attr_reader :raw, :without_ansi

  def_delegators :@without_ansi, :each_char, :each_byte, :index,
    :match, :=~

  def initialize(str)
    process_string raw_string_for(str)
  end

  def +(other)
    self.class.new @raw + raw_string_for(other)
  end

  def <<(other)
    range = length..length
    str = replace_in_string(range, other)
    process_string raw_string_for(str)
    self
  end

  def [](range)
    # convert numeric position to a range
    range = (range..range) if range.is_a?(Integer)

    range_begin = range.begin
    range_end = range.exclude_end? ? range.end - 1 : range.end

    range_begin = @without_ansi.length - range.begin.abs if range.begin < 0
    range_end = @without_ansi.length - range.end.abs if range.end < 0

    str = build_string_with_ansi_for(range_begin..range_end)
    if str
      ANSIString.new str
    end
  end

  def []=(range, replacement_str)
    # convert numeric position to a range
    range = (range..range) if range.is_a?(Integer)

    range_begin = range.begin
    range_end = range.exclude_end? ? range.end - 1 : range.end

    range_begin = @without_ansi.length - range.begin.abs if range.begin < 0
    range_end = @without_ansi.length - range.end.abs if range.end < 0

    updated_string = replace_in_string(range_begin..range_end, replacement_str)
    process_string raw_string_for(updated_string)
    self
  end

  # See String#rindex for arguments
  def rindex(*args)
    @without_ansi.rindex(*args)
  end

  def replace(str)
    process_string raw_string_for(str)
    self
  end

  def reverse
    str = @ansi_sequence_locations.reverse.map do |location|
      [location[:start_ansi_sequence], location[:text].reverse, location[:end_ansi_sequence]].join
    end.join
    ANSIString.new str
  end

  def scan(pattern)
    results = []
    without_ansi.enum_for(:scan, pattern).each do
      md = Regexp.last_match
      if md.captures.any?
        results << md.captures.map.with_index do |_, i|
          # captures use 1-based indexing
          self[md.begin(i+1)...md.end(i+1)]
        end
      else
        results << self[md.begin(0)...md.end(0)]
      end
    end
    results
  end

  def slice(index, length=nil)
    range = nil
    index = index.without_ansi if index.is_a?(ANSIString)
    index = Regexp.new Regexp.escape(index) if index.is_a?(String)
    if index.is_a?(Integer)
      length = index unless length
      range = (index...index+length)
    elsif index.is_a?(Range)
      range = index
    elsif index.is_a?(Regexp)
      md = @without_ansi.match(index)
      capture_group_index = length || 0
      if md
        capture_group = md.offset(capture_group_index)
        range = (capture_group.first...capture_group.last)
      end
    else
      raise(ArgumentError, "Must pass in at least an index or a range.")
    end
    self[range] if range
  end

  def split(*args)
    raw.split(*args).map { |s| ANSIString.new(s) }
  end

  def strip
    ANSIString.new raw.strip
  end

  def length
    @without_ansi.length
  end

  def lines
    result = []
    current_string = ""
    @ansi_sequence_locations.map do |location|
      if location[:text] == "\n"
        result << ANSIString.new(current_string + "\n")
        current_string = ""
        next
      end

      location[:text].scan(/.*(?:\n|$)/).each_with_index do |line, i|
        break if line == ""

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
      str << build_string_with_ansi_for(index..@without_ansi.length)
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

  def <=>(other)
    (other.class == self.class && @raw <=> other.raw)
  end

  private

  def raw_string_for(str)
    str.is_a?(ANSIString) ? str.raw : str.to_s
  end

  def process_string(raw_str)
    @without_ansi = ""
    @ansi_sequence_locations = []
    raw_str.enum_for(:scan, /(\e\[[0-9;]*m)?(.*?)(?=\e\[[0-9;]*m|\Z)/m ).each do
      md = Regexp.last_match
      ansi_sequence, text = md.captures

      previous_sequence_location = @ansi_sequence_locations.last
      if previous_sequence_location
        if ansi_sequence == "\e[0m"
          previous_sequence_location[:end_ansi_sequence] = ansi_sequence
          ansi_sequence = nil
        elsif previous_sequence_location[:start_ansi_sequence] == ansi_sequence
          previous_sequence_location[:text] << text
          previous_sequence_location[:ends_at] += text.length
          previous_sequence_location[:length] += text.length
          @without_ansi << text
          next
        end
      end

      if ansi_sequence.nil? && text.to_s.length == 0
        next
      end

      @ansi_sequence_locations.push(
        begins_at: @without_ansi.length,
        ends_at: [@without_ansi.length + text.length - 1, 0].max,
        length: text.length,
        text: text,
        start_ansi_sequence: ansi_sequence
      )

      @without_ansi << text
    end

    @raw = @ansi_sequence_locations.map do |location|
      [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].compact.join
    end.join

    @ansi_sequence_locations
  end

  def replace_in_string(range, replacement_str)
    raise RangeError, "#{range.inspect} out of range" if range.begin > length
    return replacement_str if @ansi_sequence_locations.empty?

    range = range.begin..(range.end - 1) if range.exclude_end?
    str = ""
    @ansi_sequence_locations.each_with_index do |location, j|
      # If the given range encompasses part of the location, then we want to
      # include the whole location
      if location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        end_index = range.end - location[:begins_at] + 1

        str << [
          location[:start_ansi_sequence],
          replacement_str,
          location[:text][end_index..-1],
          location[:end_ansi_sequence]
        ].join

      # If the location falls within the given range then  make sure we pull
      # out the bits that we want, and keep ANSI escape sequenece intact while
      # doing so.
      elsif location[:begins_at] <= range.begin && location[:ends_at] >= range.end
        start_index = range.begin - location[:begins_at]
        end_index = range.end - location[:begins_at] + 1

        str << [
          location[:start_ansi_sequence],
          location[:text][0...start_index],
          replacement_str,
          location[:text][end_index..-1],
          location[:end_ansi_sequence]
        ].join

      elsif location[:ends_at] == range.begin
        start_index = range.begin - location[:begins_at]
        end_index = range.end
        num_chars_to_remove_from_next_location = range.end - location[:ends_at]

        str << [
          location[:start_ansi_sequence],
          location[:text][location[:begins_at]...(location[:begins_at]+start_index)],
          replacement_str,
          location[:text][end_index..-1],
          location[:end_ansi_sequence],
        ].join

        if location=@ansi_sequence_locations[j+1]
          old = location.dup
          location[:text][0...num_chars_to_remove_from_next_location] = ""
          location[:begins_at] += num_chars_to_remove_from_next_location
          location[:ends_at] += num_chars_to_remove_from_next_location
        end

      # If we're pushing onto the end of the string
      elsif range.begin == length && location[:ends_at] == length - 1
        if replacement_str.is_a?(ANSIString)
          str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence], replacement_str].join
        else
          str << [location[:start_ansi_sequence], location[:text], replacement_str, location[:end_ansi_sequence]].join
        end
      else
        str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].join
      end
    end

    str
  end

  def build_string_with_ansi_for(range)
    return nil if range.begin > length

    str = ""

    if range.exclude_end?
      range = range.begin..(range.end - 1)
    end

    @ansi_sequence_locations.each do |location|
      # If the given range encompasses part of the location, then we want to
      # include the whole location
      if location[:begins_at] >= range.begin && location[:ends_at] <= range.end
        str << [location[:start_ansi_sequence], location[:text], location[:end_ansi_sequence]].join

      elsif location[:begins_at] >= range.begin && location[:begins_at] <= range.end
        str << [location[:start_ansi_sequence], location[:text][0..(range.end - location[:begins_at])], location[:end_ansi_sequence]].join

      # If the location falls within the given range then  make sure we pull
      # out the bits that we want, and keep ANSI escape sequenece intact while
      # doing so.
      elsif (location[:begins_at] <= range.begin && location[:ends_at] >= range.end) || range.cover?(location[:ends_at])
        start_index = range.begin - location[:begins_at]
        end_index = range.end - location[:begins_at]
        str << [location[:start_ansi_sequence], location[:text][start_index..end_index], location[:end_ansi_sequence]].join
      end
    end
    str
  end

end
