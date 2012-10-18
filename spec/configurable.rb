require 'mattock'

describe Mattock::Configurable do
  class TestSuperStruct
    include Mattock::Configurable

    setting(:three, 3)
    required_field(:four)
  end

  class TestStruct < TestSuperStruct
    settings(:one => 1, :two => nested(:a => "a"){ required_field(:b)} )
    nil_field(:five)
  end

  subject do
    TestStruct.new.setup_defaults
  end

  it "should set defaults" do
    subject.one.should == 1
    subject.two.a.should == "a"
    subject.three.should == 3
    subject.five.should be_nil
  end

  it "#to_hash" do
    hash = subject.to_hash
    hash[:one].should == 1
    hash[:two][:a].should == "a"
  end

  it "should complain about unset required fields" do
    expect do
      subject.check_required
    end.to raise_error
  end

  it "should complain about unset nested required fields" do
    subject.four = 4
    expect do
      subject.check_required
    end.to raise_error
  end

  it "should not complain when required fields are set" do
    subject.four = 4
    subject.two.b = "b"
    expect do
      subject.check_required
    end.to_not raise_error
  end

  describe "copying settings" do
    class LeftStruct
      include Mattock::Configurable

      setting(:normal, 1)
      setting(:no_copy, 2).isnt(:copiable)
      setting(:no_proxy, 3).isnt(:proxiable)
      setting(:no_nothing, 4).isnt(:copiable).isnt(:proxiable)
      setting(:not_on_target, 5)
    end

    class RightStruct
      include Mattock::Configurable

      required_fields(:normal, :no_copy, :no_proxy, :no_nothing)
    end

    let :left do
      LeftStruct.new.setup_defaults
    end

    let :right do
      RightStruct.new.setup_defaults
    end

    it "should not copy no_copy" do
      left.copy_settings.to(right)
      right.unset?(right.normal).should be_false
      right.normal.should == 1
      right.unset?(right.no_copy).should be_true
      right.unset?(right.no_proxy).should be_false
      right.no_proxy.should == 3
      right.unset?(right.no_nothing).should be_true
    end

    it "should not proxy no_proxy" do
      left.proxy_settings.to(right)
      right.unset?(right.normal).should be_false
      right.normal.should == 1
      right.unset?(right.no_copy).should be_false
      right.no_copy.should == 2
      right.unset?(right.no_proxy).should be_true
      right.unset?(right.no_nothing).should be_true
    end
  end
end
