require "./base"

class Present < Base
  def initialize(@index = 0, @size = 0)
    @value = ""
  end

  def +(other)
    if other.is_a? Present
      Present.new @index, @size + other.size
    else
      super.+(other)
    end
  end
end
