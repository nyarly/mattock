describe Mattock::Configurable do
  class TestSuperStruct
    include Mattock::Configurable

    setting(:three, 3)
    required_field(:four)
  end

  class TestStruct < TestSuperStruct
    settings(:one => 1, :two => nested(:a => "a").required_field(:b))
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
end
