class Parser
  def initialize(stream)
    @stream = stream
  end

  def try(string)
    puts "parsing \"#{string}\""

    return false unless @stream.starts_with? string

    @stream = @stream[string.size..-1]
    true
  end

  def parse
    root && @stream.empty?
  end
end
