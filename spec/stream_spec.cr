require "spec"
require "../stream/*"

macro spec_stream(klass, stream)
  describe "{{ klass }}" do
    it "returns its size" do
      {{ stream }}.size.should eq 12
    end

    it "matches strings" do
      {{ stream }}.matches?("abc").should be_true
    end

    it "skips first whitespaces" do
      {{ stream }}.skipped.should eq 2
    end

    it "resets skips" do
      %stream = {{ stream }}

      %stream.skipped.should eq 2
      %stream.skipped.should eq 0
    end

    it "skips after match" do
      %stream = {{ stream }}

      %stream.matches?("abca").should be_true
      %stream.skipped.should eq 1
    end

    it "doesn't skip after match" do
      %stream = {{ stream }}

      %stream.matches?("abc").should be_true
      %stream.skipped.should eq 0
    end

    it "fails to match strings" do
      {{ stream }}.matches?("abb").should be_false
    end

    it "matches regex" do
      {{ stream }}.matches?(/ab...bb/).should be_true
    end

    it "fails to match regex" do
      {{ stream }}.matches?(/[^a]b...bb/).should be_false
    end

    it "fails to match regex longer than stream" do
      {{ stream }}.matches?(/ab...bbbc/).should be_false
    end

    it "fails to match regex at a later position" do
      {{ stream }}.matches?(/b/).should be_false
    end

    it "matches the whole stream with strings" do
      %stream = {{ stream }}

      %stream.matches?("abca").should be_true
      %stream.matches?("bbb").should be_true

      %stream.empty?.should be_true
    end

    it "matches the whole stream with regexes" do
      %stream = {{ stream }}

      %stream.matches?(/ab.a/).should be_true
      %stream.matches?(/b{3}/).should be_true

      %stream.empty?.should be_true
    end

    it "fails to match string longer than stream" do
      {{ stream }}.matches?("abcabbbb").should be_false
    end

    it "doesn't make progress when requested" do
      %stream = {{ stream }}

      %stream.matches?("abc", false).should be_true
      %stream.matches?("abca").should be_true
      %stream.matches?("bbb").should be_true
    end

    it "seeks the index" do
      %stream = {{ stream }}

      %stream.matches?("abc").should be_true
      %stream.seek 3
      %stream.matches?("bca").should be_true
    end
  end
end

spec_stream StringStream, StringStream.new("  abca bbb  ", /\ /)
