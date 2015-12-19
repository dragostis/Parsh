require "./parser"

class MyParser < Parser
  rules do
    # n = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey" & b
    n = ("a".cap & "b" & ("e".pres? & "e" & "q".abs?).cap), Nar = Node.new(:baz, :bor)
    root = "a" & root.opt
  end
end

p MyParser.new("aaa").parse
