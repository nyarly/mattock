require 'mattock/cascading-definition'
require 'rake/task'

module Mattock
  class Task < Rake::Task
    include CascadingDefinition

    setting :task_name
    setting :task_args

    def self.default_taskname(name)
      setting(:task_name, name)
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
end
