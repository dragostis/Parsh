require "spec"
require "../parser"
require "../stream/string_stream"

class JSONParser < Parser
  rules do
    object = "{" & pair & ("," & pair)[0] & "}" | "{" & /./.abs?[0] & "}", ObjectLiteral = Node.new :pairs
    pair = string & ":" & value, PairLiteral = Node.new :string, :value

    array = "[" & value & ("," & value)[0] & "]" | "[" & /./.abs?[0] & "]", ArrayLiteral = Node.new :values

    value = string | number | object | array | boolean | null

    string = "\"" & (escape | /[^"\\]/)[0].cap & "\"", StringLiteral = Node.new :value
    escape = "\\" & (/[bfnrt"\\\/]/ | unicode)
    unicode = "u" & hex & hex & hex & hex
    hex = /[0-9a-fA-F]/
    number = ("-".opt & integer & "." & /[0-9]/[1] & exponent.opt |
             "-".opt & integer & exponent.opt).cap, NumberLiteral = Node.new :value

    integer = "0" | /[1-9]/ & /[0-9]/[0]
    exponent = ("E" | "e") & ("+" | "-").opt & integer

    boolean = ("true" | "false").cap, BooleanLiteral = Node.new :value

    null = "null", NullLiteral = Node.new

    space = /[ \t\n\r]/[1]

    root = object | array
  end
end

def captures(string, capture)
  parser = JSONParser.new StringStream.new string

  result = parser.parse

  result.should eq capture
end

macro fails(string, error = nil)
  %parser = JSONParser.new StringStream.new {{ string }}

  %result = %parser.parse

  {% if error == nil %}
    %result.is_a?(Error).should be_true
  {% else %}
    %result.should eq {{ error }}
  {% end %}
end

describe "JSON parser" do
  it "fails on empty string" do
    fails ""
  end

  it "captures empty objects" do
    captures "{}", JSONParser::ObjectLiteral.new [] of Node, 0, 2
  end
end
