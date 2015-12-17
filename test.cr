require "./parser.cr"
require "./grammar"

class MyParser < Parser
  include Grammar

  rules do
    root = "hi" | "you" & ("q" | "p")[2, 5]
    b = "a"
  end
end

p MyParser.new("youqpqpqp").parse
