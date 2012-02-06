require 'mattock/cascading-definition'
require 'rake/task'
require 'rake/file_task'

module Mattock
  # A configurable subclass of Rake::Task, such that you can use a
  # configuration block to change how a common task behaves, while still
  # overriding Rake API methods like Task#needed? and Task#timestamp

  module TaskMixin
    include CascadingDefinition

    setting :task_name
    setting :task_args

    module ClassMethods
      def default_taskname(name)
        setting(:task_name, name)
      end
    end

    def self.included(mod)
      mod.class_eval{ extend ClassMethods }
      super
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

    # I continue to look for an alternative here.
    def task_class
      return @task_class if @task_class
      @task_class = Class.new(self.class) do
        define_method :initialize, Rake::Task.instance_method(:initialize)
      end
    end

    def inspect
      "#{self.class.name}: #{self.task_args.inspect}"
    end

    def define
      task = task_class.define_task(*task_args) do
        action
      end
      copy_settings_to(task)
    end
  end

  class Task < Rake::Task
    include TaskMixin
  end

  class FileTask < Rake::FileTask
    include TaskMixin
  end
end
