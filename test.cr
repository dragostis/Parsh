require "./parser"

class MyParser < Parser
  rules do
    root = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey" & b
    b = "a", Nar = Node.new(:baz, :bor)
  end
end

p MyParser.new("youqpqpqheya").root
