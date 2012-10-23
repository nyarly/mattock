require 'mattock/cascading-definition'
require 'singleton' #Rake fails to require this properly
require 'rake/task'
require 'rake/file_task'
require 'rake/file_creation_task'
require 'rake/multi_task'

module Mattock
  # A configurable subclass of Rake::Task, such that you can use a
  # configuration block to change how a common task behaves, while still
  # overriding Rake API methods like Task#needed? and Task#timestamp

  module TaskMixin
    include CascadingDefinition
    include DeferredDefinition

    setting :task_name
    setting :task_args

    module ClassMethods
      def default_taskname(name)
        setting(:task_name, name)
      end
    end

    def self.included(mod)
      super
      mod.class_eval do
        extend ClassMethods
        DeferredDefinition.add_settings(self)
      end
    end

    def initialize(*args)
      configs = args.take_while{|arg| Configurable === arg}
      @extracted_task_args = args[configs.length..-1]
      if @extracted_task_args.any?{|arg| Configurable === arg}
        raise "Mattock::Task classes should be created with parent configs, then Rake task args"
      end
      super(*configs)
    end

    def resolve_configuration
      super
      if @extracted_task_args.empty?
        self.task_args = [task_name]
      else
        self.task_args = @extracted_task_args
      end
    end

    def action
    end


    module ChildTask
      attr_accessor :source_task

      def unset_defaults_guard
        source_task.unset_defaults_guard
      end

      def inspect
        "From: " + source_task.inspect
      end
    end

=begin
    # I continue to look for an alternative here.
    # The trouble is that deep inside of define_task, Rake actually
    # instantiates the Task - so in wanting to be able to override members of
    # Task, it's hard to get the virtues of CascadingDefinition as well (maybe
    # the virtues could be had without the actual mixin?)
    #
    # So, what we're doing is to dynamically create a child class and then
    # carry forward the Rake::Task#initialize
=end
    def task_class
      return @task_class if @task_class
      @task_class = Class.new(self.class) do
        define_method :initialize, Rake::Task.instance_method(:initialize)
        include ChildTask
      end
    end

    def inspect
      "#{self.class.name}: #{self.task_args.inspect}"
    end

    attr_accessor :rake_task
    def define
      self.rake_task = task_class.define_task(*task_args) do
        finalize_configuration
        copy_settings_to(rake_task)
        rake_task.action
      end
      copy_settings_to(rake_task)
      rake_task.source_task = self
    end
  end

  #I'm having misgivings about this design choice.  Rightly, this is probably a
  #"Task Definer" that knows what class to ::define_task and then mixin a
  #module to handle the original purpose of being able to override e.g.
  ##needed?  There's a lot of client code that relies on this pattern now,
  #though.
  class Task < Rake::Task
    include TaskMixin
  end

  class FileTask < Rake::FileTask
    include TaskMixin
  end

  class FileCreationTask < Rake::FileCreationTask
    include TaskMixin
  end

  class MultiTask < Rake::MultiTask
    include TaskMixin
  end
end
