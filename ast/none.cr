require "./base"

class None < Base
  def initialize(@index = 0, @size = 0)
    @value = ""
  end
end
