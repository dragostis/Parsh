require "./grammar"
require "./ast/*"

class Parser
  include Grammar

  def initialize(@stream)
    @progress = true
    @fake = false
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
