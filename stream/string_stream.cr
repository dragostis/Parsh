class StringStream
  getter :index

  def initialize(@string)
    @index = 0
  end

  def seek(@index)
  end

  def size
    @string.size
  end

  def [](range)
    @string[range]
  end

  def matches?(string : String, progress = true)
    size = @string.size

    string.each_char_with_index do |c, i|
      unless (i + @index) < size && @string[@index + i] == c
        return false
      end
    end

    @index += string.size if progress

    true
  end

  def matches?(regex : Regex, progress = true)
    result = @string.match regex, @index

    if result.is_a? Regex::MatchData
      matches = @index == result.byte_begin

      @index = result.byte_end if matches && progress

      matches
    else
      false
    end
  end

  def empty?
    @index == @string.size
  end
end
