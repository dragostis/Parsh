require "./node"

class Repetition < Node
  getter :nodes

  def initialize(@nodes, @index = 0, @size = 0)
  end

  def ==(other)
    if other.is_a? Repetition
      @nodes == other.nodes
    else
      false
    end
  end
end
