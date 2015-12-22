require "./node"

class Base < Node
  getter :value

  def initialize(@value, @index = 0, @size = 0)
  end

  def +(other)
    Base.new(
      @value + other.value,
      [@index, other.index].min,
      @size + other.size
    )
  end

  def ==(other)
    if other.is_a? Base
      @value == other.value && @index == other.index && @size == other.size
    else
      false
    end
  end
end
