require "./grammar"

class Parser
  include Grammar

  def initialize(@stream)
    @progress = true
  end

  def progress
    @progress = !@progress
  end

  def stream_index
    @stream.index
  end

  def revert(index)
    @stream.seek index
  end

  def try(string)
    puts "Parsing: #{string}"

    @stream.matches? string, @progress
  end

  def parse
    current = root

    if @stream.empty?
      current
    else
      Grammar::Absent
    end
  end
end
