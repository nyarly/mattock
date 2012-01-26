require 'mattock/task'
require 'mattock/command-line'

module Mattock
  class CommandTask < Task
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

    def action
      decorated(command).must_succeed!
    end

    def needed?
      unless verify_command.nil?
        !decorated(verify_command).succeeds?
      else
        super
      end
    end
  end
end
