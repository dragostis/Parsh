require "./parser"
require "./stream/string_stream"
require "./grammar"

class MyParser < Parser
  rules do
    # n = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey" & b
    n = ("a".cap & "b" & ("e".pres? & "e" & "q".abs?).cap), Nar = Node.new(:baz, :bor)
    root = "a".abs? | "b"
  end
end

p MyParser.new(StringStream.new "b").parse
