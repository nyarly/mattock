require 'mattock/task'
require 'mattock/command-line'

module Mattock
  class CommandTask < Task
    include CommandLineDSL

    setting(:task_name, :run)
    runtime_setting(:verify_command, nil)
    runtime_setting(:command)

    def verify_command
      if @verify_command.respond_to?(:call)
        @verify_command = @verify_command.call
      end
      @verify_command
    end

    def decorated(command)
      command
    end

    def action
      decorated(command).must_succeed!
    end

    def needed?
      finalize_configuration
      unless verify_command.nil?
        !decorated(verify_command).succeeds?
      else
        super
      end
    end
  end
end
