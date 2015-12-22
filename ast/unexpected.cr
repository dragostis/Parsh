require "./absent"

class Unexpected < Error
  getter :unexpected

  def initialize(@unexpected, @index, @size)
  end

  def |(other)
    if other.is_a? Absent
      expected = other.expected + ["not " + @unexpected]
      Absent.new expected, @index, [@size, other.size].max
    else
      other
    end
  end

  def ==(other)
    if other.is_a? Unexpected
      @unexpected == other.unexpected &&
        @index == other.index &&
        @size == other.size
    else
      false
    end
  end

  def raise
    raise "Not expecting #{@unexpected} at index #{@index}."
  end
end
