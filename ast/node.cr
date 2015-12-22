class Node
  getter :index
  getter :size

  def initialize(@index = 0, @size = 0)
  end

  macro inherited
    def ==(other)
      other.is_a? {{ @type.name }}
    end
  end
end
