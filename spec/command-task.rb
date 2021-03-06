require 'mattock/remote-command-task'
require 'mattock/bundle-command-task'

require 'mattock/testing/rake-example-group'
require 'caliph/testing/mock-command-line'

describe Mattock::RemoteCommandTask do
  include Mattock::RakeExampleGroup
  include Caliph::CommandLineExampleGroup

  let! :remote_task do
    namespace :test do
      Mattock::Rake::RemoteCommandTask.define_task do |t|
        t.remote_server.address = "nowhere.com"
        t.command = t.cmd do |cmd|
          cmd.from("cd", "a_dir")
          cmd &= "ls"
          cmd |= "grep"
          cmd.options << "*.rb"
          cmd.redirect_stderr("/dev/null")
          cmd.redirect_stdout("/tmp/rubyfiles.txt")
        end
        t.verify_command = t.cmd("should_do")
      end
    end
  end

  it "should inspect cleanly" do
    rake["test:run"].inspect.should be_a(String)
  end

  describe "when verification indicates command should proceed" do
    it "should run both commands" do
      expect_command(/should_do/, 1)
      expect_command(/^ssh.*cd.*ls.*grep.*rubyfiles.txt/, 0)

      rake["test:run"].invoke
    end
  end
end

describe Mattock::BundleCommandTask do
  include Mattock::RakeExampleGroup
  include Caliph::CommandLineExampleGroup

  let! :bundle_task do
    Mattock::BundleCommandTask.define_task(:bundle_test) do |t|
      t.command = cmd("bundle", "install", "--standalone")
    end
  end

  it "should run command" do
    expect_command(/bundle install/, 0)
    rake["bundle_test"].invoke
  end
end
