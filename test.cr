require "./parser"
require "./stream/string_stream"
require "./grammar"

class MyParser < Parser
  rules do
    # n = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey" & b
    n = ("a".cap & "b" & ("a" & "b").cap), Nar = Node.new(:baz, :bor)
    rule = "a", Problem = Error.new "Problem. Big one."
    root = rule
  end
end

p MyParser.new(StringStream.new "a").parse
