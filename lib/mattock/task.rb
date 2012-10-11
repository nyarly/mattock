require 'mattock/cascading-definition'
require 'rake/task'
require 'rake/file_task'

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

    def define
      task = task_class.define_task(*task_args) do
        finalize_configuration
        task.action
      end
      task.source_task = self
      copy_settings_to(task)
    end
  end

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
