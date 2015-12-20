require "spec"
require "../stream/*"

macro spec_stream(klass, stream)
  describe "{{ klass }}" do
    it "returns its size" do
      {{ stream }}.size.should eq 7
    end

    it "matches strings" do
      {{ stream }}.matches?("abc").should be_true
    end

    it "fails to match strings" do
      {{ stream }}.matches?("abb").should be_false
    end

    it "matches the whole stream" do
      %stream = {{ stream }}

      %stream.matches?("abc").should be_true
      %stream.matches?("abbb").should be_true

      %stream.empty?.should be_true
    end

    it "fails to match string longer than stream" do
      {{ stream }}.matches?("abcabbbb").should be_false
    end

    it "doesn't make progress when requested" do
      %stream = {{ stream }}

      %stream.matches?("abc", false).should be_true
      %stream.matches?("abc").should be_true
      %stream.matches?("abbb").should be_true
    end

    it "seeks the index" do
      %stream = {{ stream }}

      %stream.matches?("abc").should be_true
      %stream.seek 1
      %stream.matches?("bca").should be_true
    end
  end
end

spec_stream StringStream, StringStream.new "abcabbb"
