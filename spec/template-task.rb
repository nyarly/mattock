require 'mattock/template-task'
require 'mattock/testing/rake-example-group'

describe Mattock::TemplateTask do

  include Mattock::RakeExampleGroup

  class StructX < Mattock::Configurable::Struct
    setting :planet
  end


  let :test_struct do
    StructX.new.tap do |struct|
      struct.planet = "World"
    end
  end

  before :each do
    FileUtils::mkdir("templates")
    File::open("templates/test.txt.erb", "w") do |template|
      template.write("Hello, <%= planet %>!")
    end
    Mattock::TemplateTask.define_task(test_struct, "test.txt") do |task|
      task.search_dirs << "."
    end
  end

  it "should create a task" do
    rake.should have_task("test.txt")
  end

  it "should generate the file when invoked" do
    rake["test.txt"].invoke
    File::read("test.txt").should == "Hello, World!"
  end
end
