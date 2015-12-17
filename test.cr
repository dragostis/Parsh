require "./parser"

class MyParser < Parser
  rules do
    root = "hi" | "you" & ("q" | "p")[2, 5] & "he".pres? & "hey"
    b = "a"
  end
end

p MyParser.new("youqpqpqhey").parse
