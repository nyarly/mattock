require 'mattock/remote-command-task'
require 'mattock/testing/rake-example-group'
require 'mattock/testing/mock-command-line'

describe Mattock::RemoteCommandTask do
  include Mattock::RakeExampleGroup
  let! :remote_task do
    Mattock::RemoteCommandTask.new do |t|
      t.namespace_name = :test
      t.remote_server.address = "nowhere.com"
      t.command = Mattock::PrereqChain.new do |prereq|
        prereq.add Mattock::CommandLine.new("cd", "a_dir")
        prereq.add Mattock::PipelineChain.new do |pipe|
          pipe.add Mattock::CommandLine.new("ls")
          pipe.add Mattock::CommandLine.new("grep") do |cmd|
            cmd.options << "*.rb"
            cmd.redirect_stderr("/dev/null")
            cmd.redirect_stdout("/tmp/rubyfiles.txt")
          end
        end
      end
      t.verify_command = Mattock::CommandLine.new("should_do")
    end
  end

  describe "when verification indicates command should proceed" do
    it "should run both commands" do
      cmds = [/should_do/, /^ssh.*cd.*ls.*grep.*rubyfiles.txt/]
      res = [1, 0]
      Mattock::CommandLine.should_receive(:execute) do |cmd|
        cmd.should =~ cmds.shift
        Mattock::MockCommandResult.create(res.shift)
      end.exactly(2).times

      rake["test:run"].invoke
      cmds.should == []
    end
  end
end
