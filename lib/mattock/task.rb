require 'mattock/cascading-definition'
require 'calibrate'
require 'singleton' #Rake fails to require this properly
require 'rake/task'
require 'rake/file_task'
require 'rake/file_creation_task'
require 'rake/multi_task'

module Mattock
  # A configurable subclass of Rake::Task, such that you can use a
  # configuration block to change how a common task behaves, while still
  # overriding Rake API methods like Task#needed? and Task#timestamp
  module ConfigurableTask
    include Calibrate::Configurable
    include CascadingDefinition
    include DeferredDefinition
    include Calibrate::Configurable::DirectoryStructure

    module ClassMethods
      def default_taskname(name)
        setting(:task_name, name)
      end

      def define_task(*args)
        configs = args.take_while{|arg| Calibrate::Configurable === arg}
        extracted_task_args = args[configs.length..-1]
        if extracted_task_args.any?{|arg| Calibrate::Configurable === arg}
          raise "Mattock::Task classes should be created with parent configs, then Rake task args"
        end

        if extracted_task_args.empty?
          extracted_task_args = [default_value_for(:task_name)]
        end

        task = ::Rake.application.define_task(self, *extracted_task_args) do |task, args|
          task.finalize_configuration
          task.action(args)
        end

        #XXX ?? Dilemma: this prevents an existing task action from being
        #enriched with this one, but not v/v - it also doesn't prevent double
        #-definition of this task...
        unless self === task
          raise "Task already defined for #{task.name} - attempted to redefine with #{self.name}"
        end

        task.setup_deferred
        task.setup_cascade(*configs) do |t|
          t.task_name = task.name
          t.task_args = extracted_task_args

          yield(t) if block_given?
        end
        return task
      end
    end

    def self.included(sub)
      sub.extend ClassMethods
      Calibrate::Configurable.included(sub)
      Calibrate::Configurable::DirectoryStructure.included(sub)
      DeferredDefinition.add_settings(sub)
      sub.setting :task_name
      sub.setting :task_args
    end

    attr_accessor :base_task

    def resolve_configuration
      super
    end

    def action(*task_args)
    end

    def inspect
      "#{self.class.name}: #{self.task_args.inspect}\nConfiguration:\n#{self.class.inspect_instance(self, "  ")}"
    end
  end

  class DeprecatedTaskAPI
    def self.deprecated(message)
      @deprecations ||= {}
      unless @deprecations.has_key?(message)
        warn message
        @deprecations[message] = :delivered
      end
    end

    def initialize(*args, &block)
      self.class.deprecated "#{self.class.name}.new(...) is deprecated - instead use #{target_class.name}.define_task(...)\n  (from #{caller[0]})"
      target_class.define_task(*args, &block)
    end
  end

  module Rake
    class Task < ::Rake::Task
      include ConfigurableTask
    end

    class FileTask < ::Rake::FileTask
      include ConfigurableTask
    end

    class FileCreationTask < ::Rake::FileCreationTask
      include ConfigurableTask
    end

    class MultiTask < ::Rake::MultiTask
      include ConfigurableTask
    end
  end

  class Task < DeprecatedTaskAPI
    def target_class; Rake::Task; end
  end

  class FileTask < DeprecatedTaskAPI
    def target_class; Rake::FileTask; end
  end
end
