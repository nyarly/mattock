require 'mattock/tasklib'
require 'mattock/command-line'

module Mattock
  module NeededPredicate
    def needed_predicate(&block)
      (class << self; self; end).instance_eval do
        define_method(:needed?, &block)
      end
    end
  end

  class CommandTask < TaskLib
    setting(:task_name, :run)
    setting(:command)
    setting(:verify_command, nil)

    def verify_command
      if @verify_command.respond_to?(:call)
        @verify_command = @verify_command.call
      end
      @verify_command
    end

    def decorated(cmd)
      cmd
    end

    def command_task
      @command_task ||=
        begin
          task task_name do
            decorated(command).must_succeed!
          end
        end
    end

    def define
      in_namespace do
        command_task
        unless verify_command.nil?
          needed = decorated(verify_command)
          command_task.extend NeededPredicate
          command_task.needed_predicate do
            !needed.succeeds?
          end
        end
      end
    end
  end
end
