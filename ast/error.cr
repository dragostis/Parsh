require "./node"

class Error < Node
  getter :message

  def initialize(@message, @index, @size)
  end

  def |(other)
    self
  end

  def ==(other)
    if other.is_a? Error
      @message == other.message &&
        @index == other.index &&
        @size == other.size
    else
      false
    end
  end

  def raise
    raise @message
  end
end
