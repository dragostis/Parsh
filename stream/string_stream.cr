class StringStream
  getter :index

  def initialize(@string)
    @index = 0
  end

  def seek(@index)
  end

  def matches?(string, progress = true)
    size = @string.size

    string.each_char_with_index do |c, i|
      unless (i + @index) < size && @string[@index + i] == c
        return false
      end
    end

    @index += string.size if progress

    true
  end

  def empty?
    @index == @string.size
  end
end
