require 'mattock'

describe "A two-step chain of proxy settings, that target a runtime required setting" do
  class TestRuntime
    include Mattock::Configurable

    def initialize
      setup_defaults
    end

    def runtime?
      !!@runtime
    end

    def runtime!
      @runtime = true
    end
  end

  class TestHeadStruct < TestRuntime
    runtime_setting(:value)
  end

  class TestMiddleStruct < TestRuntime
    required_field(:value)
  end

  class TestTailStruct < TestRuntime
    required_field(:value)
  end

  let :head do
    TestHeadStruct.new
  end

  let :middle do
    TestMiddleStruct.new.tap do |middle|
      head.proxy_settings_to(middle)
    end
  end

  let :tail do
    TestTailStruct.new.tap do |tail|
      tail.value = middle.proxy_value.value

    end
  end

  describe "when the setting is left unset at runtime" do
    it "should not complain about unset settings at define time" do
      #expect do
        head.check_required
        middle.check_required
        tail.check_required
      #end.not_to raise_error
    end

    it "should complain about unset settings on head at runtime" do
      head.runtime!
      expect do
        head.check_required
      end.to raise_error
    end

    it "should complain about unset settings on middle at runtime" do
      middle.runtime!
      expect do
        middle.check_required
      end.to raise_error
    end

    it "should complain about unset settings on tail at runtime" do
      tail.runtime!
      expect do
        tail.check_required
      end.to raise_error
    end
  end

  shared_examples_for "a set value" do
    it "should not complain about unset settings" do
      expect do
        tail.check_required
      end.not_to raise_error
    end

    it "should report the set value at the tail" do
      tail.value.should eql(set_value)
    end
  end

  let :set_value do
    "value"
  end

  describe "when the setting is made at runtime" do
    before do
      [tail, middle, head].each do |struct|
        struct.runtime!
      end
    end

    describe "on the head of the chain" do
      before do
        head.value = set_value
      end

      it_should_behave_like "a set value"
    end

    describe "on the end of the chain" do
      before do
        tail.value = set_value
      end

      it_should_behave_like "a set value"
    end
  end

  describe "when the setting is made at define time" do
    describe "on the head of the chain" do
      before :each do
        head.value = set_value
        [tail, middle, head].each do |struct|
          struct.runtime!
        end
      end
      it_should_behave_like "a set value"
    end

    describe "on the end of the chain" do
      before :each do
        tail.value = set_value
        [tail, middle, head].each do |struct|
          struct.runtime!
        end
      end
      it_should_behave_like "a set value"
    end
  end
end
