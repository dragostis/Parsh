require "./grammar"

class Parser
  include Grammar

  def initialize(stream)
    @stream = stream
    @progress = true
  end

  def progress
    @progress = !@progress
  end

  def try(string)
    puts "parsing \"#{string}\""

    return false unless @stream.starts_with? string

    @stream = @stream[string.size..-1] if @progress
    true
  end

  def parse
    root && @stream.empty?
  end
end
