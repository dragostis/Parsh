require "./grammar"
require "./ast/*"

class Parser
  include Grammar

  def initialize(@stream)
    @progress = true
    @fake = false
    @limits = [] of Array(Int32)
  end

  def progress
    @progress = !@progress
  end

  def stream_index
    @stream.index
  end

  def read(range)
    @stream[range]
  end

  def revert(index)
    @stream.seek index
  end

  def add_limit
    @limits << [] of Int32
  end

  def limit(index, size)
    if @limits.last.empty?
      @limits.last << index
      @limits.last << size
    else
      limit = @limits.last

      limit[0] = [limit[0], index].min
      limit[1] += size
    end
  end

  def limit
    @limits.pop
  end

  def fake(&rule)
    @fake = true

    result = rule.call

    @fake = false

    result
  end

  def try(string)
    @fake || @stream.matches? string, @progress
  end

  def parse
    current = root

    if @stream.empty? || current.is_a? Error
      current
    else
      index = stream_index
      Absent.new "end of input", index, @stream.size - index
    end
  end
end
