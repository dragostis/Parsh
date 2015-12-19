require "spec"
require "../grammar"
require "../parser"
require "../stream/string_stream"

class SingleRuleParser < Parser
  rules do
    single = "single"
  end

  def empty?
    @stream.empty?
  end
end

class SpecParser < Parser
  rules do
    capture_one = "a".cap
    capture_two = "a".cap & "b".cap
    capture_two_gap = "a".cap & "b" & "c".cap
    capture_repeated = "a".cap[0]
    capture_foo = "a".cap & "b" & "c".cap, Foo = Node.new(:a, :c)
    capture_foobar = capture_foo, FooBar = Node.new(:foo)

    terminal = "a"
    terminal_cap = "a".cap
    empty_terminal = ""
    long_terminal = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    long_terminal_cap = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa".cap

    composed = "a" & "b"
    composed_cap = ("a" & "b").cap
    long_composed = "a" & "b" & "b" & "b" & "b" & "a"
    long_composed_cap = ("a" & "b" & "b" & "b" & "b" & "a").cap

    choice = "a" | "b"
    choice_cap = ("a" | "b").cap
    long_choice = "a" | "b" | "c" | "d" | "e" | "f" | "g"
    long_choice_cap = ("a" | "b" | "c" | "d" | "e" | "f" | "g").cap

    composed_choice = "a" & "b" | "a" & "c"
    composed_choice_cap = ("a" & "b" | "a" & "c").cap
    choice_composed = ("a" | "b") & ("c" | "d")
    choice_composed_cap = (("a" | "b") & ("c" | "d")).cap

    repetition_without_max = "a"[2]
    repetition_with_max = "a"[2, 5]
    repetition_cap = "a"[2, 5].cap

    composed_repetition = "a"[2, 4] & "b"[2, 4]
    composed_repetition_cap = ("a"[2, 4] & "b"[2, 4]).cap

    option = "a".opt
    option_cap = "a".opt.cap

    present = "a".pres? & "a"
    present_not_processed = "a".pres?
    present_fail = "b".pres? & "a"
    absent = "a".abs?
    present_absent_cap = ("a" & "b".pres? & "a".abs? & "b").cap

    root = "b"
  end

  def empty?
    @stream.empty?
  end
end

macro parses(rule, string, parser = SpecParser)
  %parser = {{ parser }}.new StringStream.new {{ string }}

  %result = %parser.{{ rule.id }}

  %result.should_not eq Grammar::Absent
  %parser.empty?.should be_true
end

macro fails(rule, string)
  %parser = SpecParser.new StringStream.new {{ string }}

  %result = %parser.{{ rule.id }}

  %failed = %result.is_a? Grammar::Absent || !%parser.empty?
  %failed.should be_true
end

macro captures(rule, string, capture)
  %parser = SpecParser.new StringStream.new {{ string }}

  %result = %parser.{{ rule.id }}

  %result.should eq {{ capture }}
  %parser.empty?.should be_true
end

describe "Grammar" do
  describe "rules" do
    it "parses root" do
      SpecParser.new(StringStream.new "b").parse.should_not eq Grammar::Absent
    end

    it "parses one rule" do
      parses :single, "single", SingleRuleParser
    end

    describe "captures" do
      it "captures one string" do
        captures :capture_one, "a", Grammar::Base.new "a"
      end

      it "captures two strings" do
        captures :capture_two, "ab", [
          Grammar::Base.new("a"),
          Grammar::Base.new("b")
        ]
      end

      it "captures two strings with gap" do
        captures :capture_two_gap, "abc", [
          Grammar::Base.new("a"),
          Grammar::Base.new("c")
        ]
      end

      it "captures repeated strings" do
        captures :capture_repeated, "aa", [
          Grammar::Base.new("a"),
          Grammar::Base.new("a")
        ]
      end

      it "captures object" do
        foo = SpecParser.new(StringStream.new "abc").capture_foo

        foo.is_a?(SpecParser::Foo).should be_true

        if foo.is_a? SpecParser::Foo
          foo.a.should eq Grammar::Base.new "a"
          foo.c.should eq Grammar::Base.new "c"
        end
      end

      it "captures nested objects" do
        foobar = SpecParser.new(StringStream.new "abc").capture_foobar

        foobar.is_a?(SpecParser::FooBar).should be_true

        if foobar.is_a? SpecParser::FooBar
          foo = foobar.foo

          foo.is_a?(SpecParser::Foo).should be_true

          if foo.is_a? SpecParser::Foo
            foo.a.should eq Grammar::Base.new "a"
            foo.c.should eq Grammar::Base.new "c"
          end
        end
      end
    end

    describe "terminals" do
      it "parses terminals" do
        parses :terminal, "a"
      end

      it "fails terminals on wrong strings" do
        fails :terminal, "b"
      end

      it "fails terminals on longer strings" do
        fails :terminal, "aa"
      end

      it "fails terminals on shorter strings" do
        fails :terminal, ""
      end

      it "captures terminals" do
        captures :terminal_cap, "a", Grammar::Base.new "a"
      end

      it "parses empty terminals" do
        parses :empty_terminal, ""
      end

      it "parses long terminals" do
        parses :long_terminal, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      end

      it "captures long terminals" do
        captures :long_terminal_cap, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                 Grammar::Base.new "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      end
    end

    describe "composed rules" do
      it "parses composed rules" do
        parses :composed, "ab"
      end

      it "fails composed rule first part" do
        fails :composed, "bb"
      end

      it "fails composed rule second part" do
        fails :composed, "ac"
      end

      it "captures composed rules" do
        captures :composed_cap, "ab", Grammar::Base.new "ab"
      end

      it "parses long composed rules" do
        parses :long_composed, "abbbba"
      end

      it "captures long composed rules" do
        captures :long_composed_cap, "abbbba", Grammar::Base.new "abbbba"
      end
    end

    describe "choice" do
      it "parses choice first part" do
        parses :choice, "a"
      end

      it "parses choice second part" do
        parses :choice, "b"
      end

      it "fails choices" do
        fails :choice, "c"
      end

      it "captures choices" do
        captures :choice_cap, "a", Grammar::Base.new "a"
      end

      it "parses long choices" do
        parses :long_choice, "g"
      end

      it "captures long choices" do
        captures :long_choice_cap, "g", Grammar::Base.new "g"
      end
    end

    describe "composed rules & choices" do
      it "parses composed choices" do
        parses :composed_choice, "ac"
      end

      it "captures composed choices" do
        captures :composed_choice_cap, "ac", Grammar::Base.new "ac"
      end

      it "parses choice composed rules" do
        parses :choice_composed, "bd"
      end

      it "captures choice composed rules" do
        captures :choice_composed_cap, "bd", Grammar::Base.new "bd"
      end
    end

    describe "repetitions" do
      it "parses repetitions without max" do
        parses :repetition_without_max, "aa"
      end

      it "fails repetitions without max" do
        fails :repetition_without_max, "a"
      end

      it "parses repetitions with max" do
        parses :repetition_with_max, "aaa"
      end

      it "fails repetitions with max on lower bound" do
        fails :repetition_with_max, "a"
      end

      it "fails repetitions with max on higher bound" do
        fails :repetition_with_max, "aaaaaa"
      end

      it "capture repetitions" do
        captures :repetition_cap, "aaa", Grammar::Base.new "aaa"
      end
    end

    describe "composed rules & repetitions" do
      it "parses composed repetitions" do
        parses :composed_repetition, "aaabbb"
      end

      it "captures composed repetitions" do
        captures :composed_repetition_cap, "aaabbb", Grammar::Base.new "aaabbb"
      end
    end

    describe "optionals" do
      it "parses negative optionals" do
        parses :option, ""
      end

      it "parses positive optionals" do
        parses :option, "a"
      end

      it "captures negative optionals" do
        captures :option_cap, "", Grammar::NoneType.new
      end

      it "captures positive optionals" do
        captures :option_cap, "a", Grammar::Base.new "a"
      end
    end

    describe "present/absent rules" do
      it "parses present rules" do
        parses :present, "a"
      end

      it "fails present not processed" do
        fails :present_not_processed, "a"
      end

      it "fails present rules" do
        fails :present_fail, "a"
      end

      it "parses absent empty string" do
        parses :absent, ""
      end

      it "fails absent rules" do
        fails :absent, "a"
      end

      it "fails absent not processed" do
        fails :absent, "b"
      end

      it "captures present/absent rules" do
        captures :present_absent_cap, "ab", Grammar::Base.new "ab"
      end
    end
  end
end
