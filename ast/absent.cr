require "./error"

class Absent < Error
  getter :expected

  def initialize(@expected : Set(String), @index, @size)
  end

  def initialize(expected : Array(String), @index, @size)
    @expected = expected.to_set
  end

  def initialize(expected : String, @index, @size)
    @expected = Set{expected}
  end

  def |(other)
    if other.is_a? Absent
      if other.index > @index
        other
      elsif @index > other.index
        self
      else
        expected = @expected | other.expected
        Absent.new expected, @index, [@size, other.size].min
      end
    elsif other.is_a? Unexpected
      self
    else
      other
    end
  end

  def ==(other)
    if other.is_a? Absent
      @expected == other.expected &&
        @index == other.index &&
        @size == other.size
    else
      false
    end
  end

  def raise
    raise "Expecting #{@expected.uniq.join(", ")} at index #{@index}."
  end
end
