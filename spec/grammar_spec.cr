require "spec"
require "../grammar"
require "../ast/*"
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
    absent = "a".abs? & "b"
    absent_not_processed = "a".abs?
    absent_choice = "a".abs? | "b"
    present_absent_cap = ("a" & "b".pres? & "a".abs? & "b").cap

    atomic_no_name = terminal.atom
    atomic_terminal = "a".atom("rule")
    atomic_composed = ("a" & "b").atom("rule")
    atomic_choice = ("a" | "b").atom("rule")
    atomic_repetition = "a"[2].atom("rule")
    atomic_present = "a".pres?.atom("rule")
    atomic_absent = "a".abs?.atom("rule")

    quiet = terminal.quiet
    quiet_terminal = "a".quiet
    quiet_composed = ("a" & "b").quiet
    quiet_choice = ("a" | "b").quiet
    quiet_repetition = "a"[2].quiet
    quiet_present = "a".pres?.quiet
    quiet_absent = "a".abs?.quiet

    root = "b"
  end

  def empty?
    @stream.empty?
  end
end

macro parses(rule, string, parser = SpecParser)
  %parser = {{ parser }}.new StringStream.new {{ string }}

  %result = %parser.{{ rule.id }}

  %result.should_not be_a Error
  %parser.empty?.should be_true
end

macro fails(rule, string, error = nil)
  %parser = SpecParser.new StringStream.new {{ string }}

  %result = %parser.{{ rule.id }}

  %failed = !%parser.empty?

  {% if error == nil %}
    %failed ||= %result.is_a? Error
  {% else %}
    %failed = %result == {{ error }}
  {% end %}

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
      SpecParser.new(StringStream.new "b").parse.should_not be_a Error
    end

    it "parses one rule" do
      parses :single, "single", SingleRuleParser
    end

    describe "captures" do
      it "captures one string" do
        captures :capture_one, "a", Base.new "a", 0, 1
      end

      it "captures two strings" do
        captures :capture_two, "ab", [
          Base.new("a", 0, 1),
          Base.new("b", 1, 1)
        ]
      end

      it "captures two strings with gap" do
        captures :capture_two_gap, "abc", [
          Base.new("a", 0, 1),
          Base.new("c", 2, 1)
        ]
      end

      it "doesn't capture repeated strings 0 times" do
        parses :capture_repeated, ""
      end

      it "captures repeated strings once" do
        captures :capture_repeated, "a", [
          Base.new("a", 0, 1)
        ]
      end

      it "captures repeated strings twice" do
        captures :capture_repeated, "aa", [
          Base.new("a", 0, 1),
          Base.new("a", 1, 1)
        ]
      end

      it "captures object" do
        foo = SpecParser.new(StringStream.new "abc").capture_foo

        foo.is_a?(SpecParser::Foo).should be_true

        if foo.is_a? SpecParser::Foo
          foo.a.should eq Base.new "a", 0, 1
          foo.c.should eq Base.new "c", 2, 1
        end
      end

      it "captures nested objects" do
        foobar = SpecParser.new(StringStream.new "abc").capture_foobar

        foobar.is_a?(SpecParser::FooBar).should be_true

        if foobar.is_a? SpecParser::FooBar
          foo = foobar.foo

          foo.is_a?(SpecParser::Foo).should be_true

          if foo.is_a? SpecParser::Foo
            foo.a.should eq Base.new "a", 0, 1
            foo.c.should eq Base.new "c", 2, 1
          end
        end
      end
    end

    describe "terminals" do
      it "parses terminals" do
        parses :terminal, "a"
      end

      it "fails terminals on wrong strings" do
        fails :terminal, "b", Absent.new "\"a\"", 0, 1
      end

      it "fails terminals on longer strings" do
        fails :terminal, "aa"
      end

      it "fails terminals on shorter strings" do
        fails :terminal, "", Absent.new "\"a\"", 0, 1
      end

      it "captures terminals" do
        captures :terminal_cap, "a", Base.new "a", 0, 1
      end

      it "parses empty terminals" do
        parses :empty_terminal, ""
      end

      it "parses long terminals" do
        parses :long_terminal, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      end

      it "captures long terminals" do
        captures :long_terminal_cap, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                 Base.new "aaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 0, 29
      end
    end

    describe "composed rules" do
      it "parses composed rules" do
        parses :composed, "ab"
      end

      it "fails composed rule first part" do
        fails :composed, "bb", Absent.new "\"a\"", 0, 1
      end

      it "fails composed rule second part" do
        fails :composed, "ac", Absent.new "\"b\"", 1, 1
      end

      it "captures composed rules" do
        captures :composed_cap, "ab", Base.new "ab", 0, 2
      end

      it "parses long composed rules" do
        parses :long_composed, "abbbba"
      end

      it "captures long composed rules" do
        captures :long_composed_cap, "abbbba", Base.new "abbbba", 0, 6
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
        fails :choice, "c", Absent.new ["\"a\"", "\"b\""], 0, 1
      end

      it "captures choices" do
        captures :choice_cap, "a", Base.new "a", 0, 1
      end

      it "parses long choices" do
        parses :long_choice, "g"
      end

      it "captures long choices" do
        captures :long_choice_cap, "g", Base.new "g", 0, 1
      end
    end

    describe "composed rules & choices" do
      it "parses composed choices" do
        parses :composed_choice, "ac"
      end

      it "captures composed choices" do
        captures :composed_choice_cap, "ac", Base.new "ac", 0, 2
      end

      it "parses choice composed rules" do
        parses :choice_composed, "bd"
      end

      it "captures choice composed rules" do
        captures :choice_composed_cap, "bd", Base.new "bd", 0, 2
      end
    end

    describe "repetitions" do
      it "parses repetitions without max" do
        parses :repetition_without_max, "aa"
      end

      it "fails repetitions without max" do
        fails :repetition_without_max, "a", Absent.new "\"a\"", 1, 1
      end

      it "parses repetitions with max" do
        parses :repetition_with_max, "aaa"
      end

      it "fails repetitions with max on lower bound" do
        fails :repetition_with_max, "a", Absent.new "\"a\"", 1, 1
      end

      it "fails repetitions with max on higher bound" do
        fails :repetition_with_max, "aaaaaa"
      end

      it "capture repetitions" do
        captures :repetition_cap, "aaa", Base.new "aaa", 0, 3
      end
    end

    describe "composed rules & repetitions" do
      it "parses composed repetitions" do
        parses :composed_repetition, "aaabbb"
      end

      it "captures composed repetitions" do
        captures :composed_repetition_cap, "aaabbb",
                 Base.new "aaabbb", 0, 6
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
        captures :option_cap, "", None.new 0, 0
      end

      it "captures positive optionals" do
        captures :option_cap, "a", Base.new "a", 0, 1
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
        fails :present_fail, "a", Absent.new "\"b\"", 0, 1
      end

      it "parses absent rules" do
        parses :absent, "b"
      end

      it "parses absent empty string" do
        parses :absent_not_processed, ""
      end

      it "fails absent rules" do
        fails :absent_not_processed, "a", Unexpected.new "\"a\"", 0, 1
      end

      it "fails absent not processed" do
        fails :absent_not_processed, "c"
      end

      it "failes absent choices" do
        fails :absent_choice, "a", Absent.new ["\"b\""], 0, 1
      end

      it "captures present/absent rules" do
        captures :present_absent_cap, "ab", Base.new "ab", 0, 2
      end
    end

    describe "atomic rules" do
      it "fails atomic rules with no name" do
        fails :atomic_no_name, "b", Absent.new "terminal", 0, 1
      end

      it "fails atomic terminals" do
        fails :atomic_terminal, "b", Absent.new "rule", 0, 1
      end

      it "fails atomic composed rules" do
        fails :atomic_composed, "ac", Absent.new "rule", 0, 2
      end

      it "fails atomic choices" do
        fails :atomic_choice, "c", Absent.new "rule", 0, 1
      end

      it "fails atomic repetitions" do
        fails :atomic_repetition, "a", Absent.new "rule", 1, 1
      end

      it "fails atomic present rules" do
        fails :atomic_present, "b", Absent.new "rule", 0, 1
      end

      it "fails atomic absent rules" do
        fails :atomic_absent, "a", Absent.new "rule", 0, 1
      end
    end

    describe "quiet rules" do
      it "fails quiet rules" do
        fails :quiet, "b", Unexpected.new "\"b\"", 0, 1
      end

      it "fails quite terminals" do
        fails :quiet_terminal, "b", Unexpected.new "\"b\"", 0, 1
      end

      it "fails quiet composed rules" do
        fails :quiet_composed, "ac", Unexpected.new "\"ac\"", 0, 2
      end

      it "fails quiet choices" do
        fails :quiet_choice, "c", Unexpected.new "\"c\"", 0, 1
      end

      it "fails quiet repetitions" do
        fails :quiet_repetition, "a", Unexpected.new "end of input", 1, 1
      end

      it "fails quiet present rules" do
        fails :quiet_present, "b", Unexpected.new "\"b\"", 0, 1
      end

      it "fails quiet absent rules" do
        fails :quiet_absent, "a", Unexpected.new "\"a\"", 0, 1
      end
    end
  end
end
