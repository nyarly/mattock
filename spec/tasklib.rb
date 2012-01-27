require 'mattock/tasklib'
require 'mattock/testing/rake-example-group'

describe Mattock::Tasklib do
  include Mattock::RakeExampleGroup

  class TestTaskLib < Mattock::TaskLib
    default_namespace :test
    def define
      in_namespace do
        task :task
      end

      task root_task => self[:task]
    end
  end

  let! :tasklib do
    TestTaskLib.new
  end

  describe "defines" do
    subject{ rake }

    it{ should have_task(:test) }
    it{ should have_task("test:task") }
    it{ should_not have_task("random:tasks")}
  end

  it "should make root task depend on namespaced" do
    rake[:test].should depend_on("test:task")
  end

  it "should not make namespaced task depend on root task" do
    rake["test:task"].should_not depend_on("test")
  end
end
