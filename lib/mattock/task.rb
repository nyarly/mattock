require 'mattock/cascading-definition'
require 'rake/task'

module Mattock
  class Task < Rake::Task
    include CascadingDefinition

    setting :task_name

    def action
    end

    def task_args
      [task_name]
    end

    def task_class
      return @task_class if @task_class
      @task_class = Class.new(self.class) do
        define_method :initialize, Rake::Task.instance_method(:initialize)
      end
    end

    def inspect
      "Mattock::Task"
    end

    def define
      task  =task_class.define_task(*task_args) do
        action
      end
      copy_settings_to(task)
    end
  end
end
