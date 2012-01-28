require 'mattock/command-line'
require 'mattock/testing/rake-example-group'
require 'mattock/testing/mock-command-line'

require 'mattock/testing/record-commands'

Mattock::CommandLine.command_recording_path = "/dev/null"

describe Mattock::CommandLine do
  let :commandline do
    Mattock::CommandLine.new('echo', "-n") do |cmd|
      cmd.options << "Some text"
    end
  end

  it "should have a name set" do
    commandline.name.should == "echo"
  end

  it "should produce a command string" do
    commandline.command.should == "echo -n Some text"
  end

  it "should succeed" do
    commandline.succeeds?.should be_true
  end

  it "should not complain about success" do
    expect do
      commandline.must_succeed!
    end.to_not raise_error
  end

  describe Mattock::CommandRunResult do
    let :result do
      commandline.run
    end

    it "should have a result code" do
      result.exit_code.should == 0
    end

    it "should have stdout" do
      result.stdout.should == "Some text"
    end
  end
end

describe Mattock::CommandLine, "that fails" do
  let :commandline do
    Mattock::CommandLine.new("false")
  end

  it "should not succeed" do
    commandline.succeeds?.should == false
  end

  it "should raise error if succeed demanded" do
    expect do
      commandline.must_succeed
    end.to raise_error
  end
end
