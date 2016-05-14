require "./grammar"
require "./ast/*"

class Parser
  include Grammar

  getter :fake

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
    nested = @fake

    @fake = true unless nested

    result = rule.call

    @fake = false unless nested

    result
  end

  def try(terminal)
    @fake || @stream.matches? terminal, @progress
  end

  def eoi
    index = @stream.size - stream_index

    if @stream.empty?
      Present.new index, 0
    else
      Absent.new "end of input", index, 0
    end
  end

  def eoi_cap
    index = @stream.size - stream_index

    if @stream.empty?
      Present.new index, 0
    else
      Absent.new "end of input", index, 0
    end
  end

  def parse
    current = root

    if @stream.empty? || current.is_a? Error
      current
    else
      index = stream_index
      eoi = Absent.new "end of input", index, @stream.size - index

      if current.is_a? Error
        current | eoi
      else
        eoi
      end
    end
  end
end
