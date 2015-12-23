require "./absent"

class Unexpected < Error
  getter :unexpected

  def initialize(@unexpected, @index, @size)
    @unexpected = "end of input" if @unexpected == "\"\""
  end

  def |(other)
    other
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
