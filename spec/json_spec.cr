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

    root = value
  end
end

def captures(string, capture)
  parser = JSONParser.new StringStream.new string

  result = parser.parse

  result.should eq capture
end

macro fails_json(string, error = nil)
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
    fails_json ""
  end

  it "captures null" do
    captures "null", JSONParser::NullLiteral.new 0, 4
  end

  it "captures false" do
    captures "false", JSONParser::BooleanLiteral.new Base.new("false", 0, 5), 0, 5
  end

  it "captures true" do
    captures "true", JSONParser::BooleanLiteral.new Base.new("true", 0, 4), 0, 4
  end

  it "captures zeroes" do
    captures "0", JSONParser::NumberLiteral.new Base.new("0", 0, 1), 0, 1
  end

  it "captures integers" do
    captures "8436", JSONParser::NumberLiteral.new Base.new("8436", 0, 4), 0, 4
  end

  it "captures negative integers" do
    captures "-543", JSONParser::NumberLiteral.new Base.new("-543", 0, 4), 0, 4
  end

  it "captures floats with exponents" do
    captures "1e10", JSONParser::NumberLiteral.new Base.new("1e10", 0, 4), 0, 4
  end

  it "captures floats with signed exponents" do
    captures "1e+10", JSONParser::NumberLiteral.new Base.new("1e+10", 0, 5), 0, 5
  end

  it "captures floats with capital exponents" do
    captures "1E10", JSONParser::NumberLiteral.new Base.new("1E10", 0, 4), 0, 4
  end

  it "captures floats with decimal points" do
    captures "1.00", JSONParser::NumberLiteral.new Base.new("1.00", 0, 4), 0, 4
  end

  it "captures floats with decimal points and exponents" do
    captures "1.0e-1", JSONParser::NumberLiteral.new Base.new("1.0e-1", 0, 6), 0, 6
  end

  it "captures empty strings" do
    captures "\"\"", JSONParser::StringLiteral.new Base.new("", 1, 0), 0, 2
  end

  it "captures strings" do
    captures "\"abc\"", JSONParser::StringLiteral.new Base.new("abc", 1, 3), 0, 5
  end

  it "captures escaped strings" do
    captures "\"\\n\"", JSONParser::StringLiteral.new Base.new("\\n", 1, 2), 0, 4
  end

  it "captures escaped strings with unicodes" do
    captures "\"\\u7777\"", JSONParser::StringLiteral.new Base.new("\\u7777", 1, 6), 0, 8
  end

  it "captures empty arrays" do
    captures "[]", JSONParser::ArrayLiteral.new [] of Node, 0, 2
  end

  it "captures one-element arrays" do
    captures "[null]", JSONParser::ArrayLiteral.new [
      JSONParser::NullLiteral.new(1, 4),
    ], 0, 6
  end

  it "captures multiple-element arrays" do
    captures "[null,true,1.0e-10,\"a\",[]]", JSONParser::ArrayLiteral.new [
      JSONParser::NullLiteral.new(1, 4),
      JSONParser::BooleanLiteral.new(Base.new("true", 6, 4), 6, 4),
      JSONParser::NumberLiteral.new(Base.new("1.0e-10", 11, 7), 11, 7),
      JSONParser::StringLiteral.new(Base.new("a", 20, 1), 19, 3),
      JSONParser::ArrayLiteral.new [] of Node, 23, 2
    ], 0, 26
  end

  it "captures empty objects" do
    captures "{}", JSONParser::ObjectLiteral.new [] of JSONParser::PairLiteral, 0, 2
  end

  it "captures one-element objects" do
    captures "{\"a\":null}", JSONParser::ObjectLiteral.new [
      JSONParser::PairLiteral.new(
        JSONParser::StringLiteral.new(Base.new("a", 2, 1), 1, 3),
        JSONParser::NullLiteral.new(5, 4),
        1, 8
      )
    ], 0, 10
  end

  it "captures multiple-element objects" do
    captures "{\"a\":null,\"b\":10.0e-10}", JSONParser::ObjectLiteral.new [
      JSONParser::PairLiteral.new(
        JSONParser::StringLiteral.new(Base.new("a", 2, 1), 1, 3),
        JSONParser::NullLiteral.new(5, 4),
        1, 8
      ),
      JSONParser::PairLiteral.new(
        JSONParser::StringLiteral.new(Base.new("b", 11, 1), 10, 3),
        JSONParser::NumberLiteral.new(Base.new("10.0e-10", 14, 8), 14, 8),
        10, 12
      )
    ], 0, 23
  end

  it "fails on open string" do
    fails_json "\"a", Absent.new "\"\"\"", 2, 1
  end

  it "fails on character after number" do
    fails_json "3g", Absent.new "end of input", 1, 1
  end

  it "fails on open array" do
    fails_json "[3", Absent.new "\"]\"", 2, 1
  end

  it "fails on open object" do
    fails_json "{\"a\":3", Absent.new "\"}\"", 6, 1
  end
end
