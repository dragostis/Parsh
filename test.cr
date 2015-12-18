require "./parser"

class MyParser < Parser
  rules do
    # n = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey" & b
    root = ("a".cap & "b" & ("e".pres? & "e" & "q".abs?).cap), Nar = Node.new(:baz, :bor)
  end
end

p MyParser.new("abe").parse
