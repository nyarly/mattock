require 'rake/tasklib'
require 'mattock/cascading-definition'

module Mattock
  # {Mattock::TaskLib} provides a base class to build tasklibs on so that you
  # can get to what you care about, and get option validation as well.
  #
  # The convention that's added in Mattock is that Tasklibs are passed to each
  # other as arguments, so that behavior can be composed out of modular
  # components.
  #
  # To define a new task lib: subclass {TaskLib}, add some ::setting calls, and
  # override #define to add some tasks.
  #
  # To use your tasklib, instantiate with a block, optionally passing other
  # task libs to copy configuration from.
  #
  # @example
  #     class CoolTask < Mattock::TaskLib
  #       settings :option_one, :option_two
  #
  #       default_namespace :be
  #
  #       def define
  #         task :cool do
  #           puts "I am so #{option_one} #{option_two}"
  #         end
  #       end
  #     end
  #
  #     CoolTask.new(:args) do |t|
  #       t.option_one = "cool"
  #       t.option_two = "very"
  #     end
  #
  # @example
  #     > rake be:cool
  #     I am so very cool
  #
  # @example Composition
  #     transport = HTTPTasks.new do |t|
  #       t.server = http://mycoolserver.com
  #     end
  #
  #     UploadTasks.new(transport) do |t|
  #       t.dir = "./source_dir"
  #     end
  #
  #The configuration handling is provided by {CascadingDefinition}, and
  #configuration options are built using {Configurable}
  class TaskLib < ::Rake::TaskLib
    include CascadingDefinition
    include Calibrate::Configurable::DirectoryStructure

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
    def bracket_task(before, name, after, &block)
      task self[name] => before, &block
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

    #Default define defines some tasks related to debugging Rakefiles -
    #subclasses can get these just by remembering to call 'super' in their
    #define
    def define
      debug_settings_task
    end

    def debug_settings_task
      in_namespace do
        task :debug_settings do
          require 'pp'
          puts self.class.name
          pp self.to_hash
        end
      end

      task :debug_settings => self[:debug_settings]
    end

    #Wraps a single task in lib's namespace
    def [](taskname)
      in_namespace(taskname).first
    end
  end

  #Because I can never remember
  Tasklib = TaskLib
end
