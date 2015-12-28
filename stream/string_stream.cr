class StringStream
  getter :index

  def initialize(@string, @whitespace = /$^/)
    @index = 0
    @skipped = 0

    skip
  end

  def whitespace_=(@whitespace)
    skip
  end

  def seek(@index)
  end

  def size
    @string.size
  end

  def [](range)
    @string[range]
  end

  def skipped
    result = @skipped

    @skipped = 0

    result
  end

  def skip
    (@index...@string.size).each do |i|
      unless @string[i].to_s.match @whitespace
        @skipped = i - @index
        @index = i

        return
      end
    end

    @skipped = @string.size - @index
    @index = @string.size
  end

  def matches?(string : String, progress = true)
    size = @string.size

    string.each_char_with_index do |c, i|
      unless (i + @index) < size && @string[@index + i] == c
        return false
      end
    end

    @index += string.size if progress
    skip if progress

    true
  end

  def matches?(regex : Regex, progress = true)
    result = @string.match regex, @index

    if result.is_a? Regex::MatchData
      matches = @index == result.byte_begin

      @index = result.byte_end if matches && progress
      skip if progress

      matches
    else
      false
    end
  end

  def empty?
    @index == @string.size
  end
end
