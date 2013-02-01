require 'rake/tasklib'
require 'mattock/cascading-definition'

module Mattock
  #Rake::Tasklib provides a common, well known way to generalize tasks and use
  #them in multiple projects.
  #
  #Typically, the #initialize method for CoolTask yields itself into the block
  #(so, 't' in the example) and then runs #define which does the heavy lifting
  #to actually create tasks and set them up with dependencies and whatnot.
  #
  #Rake::Tasklib doesn't really provide much in the way of help or guidance
  #about how to do this, though, and everyone winds up having to do a lot of
  #the same work.
  #
  #Mattock::TaskLib provides a base class to build tasklibs on so that you can
  #get to what you care about, and get option validation as well.
  #
  #The convention that's added in Mattock is that Tasklibs are passed to each
  #other as arguments, so that behavior can be composed out of modular
  #components.
  #
  #@example
  #    CoolTask.new(:args) do |t|
  #      t.option_one = "cool"
  #      t.option_two = "very"
  #    end
  #
  #@example Composition
  #    transport = HTTPTasks.new do |t|
  #      t.server = http://mycoolserver.com
  #    end
  #
  #    UploadTasks.new(transport) do |t|
  #      t.dir = "./source_dir"
  #    end
  #
  #The configuration handling is provided by {CascadingDefinition}, and
  #configuration options are built using {Configurable}
  class TaskLib < ::Rake::TaskLib
    include CascadingDefinition

    attr_writer :namespace_name

    #The namespace this lib's tasks will created within.  Changeable at
    #instantiation
    def self.default_namespace(name)
      setting(:namespace_name, name).isnt(:copiable)
    end

    attr_reader :tasks

    def initialize(*toolkits, &block)
      @tasks = []
      setup_cascade(*toolkits, &block)
    end

    #Records tasks as they are created
    def task(*args)
      a_task = super
      @tasks << a_task
      return a_task
    end

    #Shorthand for
    #  task name => before
    #  task after => name
    #Which ensures that if "after" is ever invoked,
    #the execution will be before, name, then after
    def bracket_task(before, name, after)
      task self[name] => before
      task after => self[name]
    end

    #Builds a series of tasks in a sequence - the idea is that
    #dependant tasklibs can depend on stages of a larger process
    def task_spine(*list)
      task list.first
      list.each_cons(2) do |first, second|
        task second => first
      end
    end

    #@overload in_namespace(args)
    #  maps the arguments to namespace-prefixed names, for use in Rake
    #  dependency declaration
    #@overload in_namespace &block
    #  wraps the block in a Rake namespace call
    def in_namespace(*tasknames)
      if tasknames.empty?
        if block_given?
          if @namespace_name.nil?
            yield
          else
            namespace @namespace_name do
              yield
            end
          end
        end
      else
        tasknames.map do |taskname|
          [@namespace_name, taskname].compact.join(":")
        end
      end
    end

    def root_task
      @namespace_name || :default
    end

    def default_namespace
      nil
    end

    #Wraps a single task in lib's namespace
    def [](taskname)
      in_namespace(taskname).first
    end
  end

  #Because I can never remember
  Tasklib = TaskLib
end
