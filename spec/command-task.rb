require 'mattock/remote-command-task'
require 'mattock/testing/rake-example-group'
require 'mattock/testing/mock-command-line'

describe Mattock::RemoteCommandTask do
  include Mattock::RakeExampleGroup
  let! :remote_task do
    namespace :test do
      Mattock::RemoteCommandTask.new do |t|
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
  end

  describe "when verification indicates command should proceed" do
    include Mattock::CommandLineExampleGroup

    it "should run both commands" do
      expect_command(/should_do/, 1)
      expect_command(/^ssh.*cd.*ls.*grep.*rubyfiles.txt/, 0)

      rake["test:run"].invoke
    end
  end
end
