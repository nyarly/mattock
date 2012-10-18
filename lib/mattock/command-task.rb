require 'mattock/task'
require 'mattock/command-line'

module Mattock
  class CommandTask < Task
    include CommandLineDSL
    extend CommandLineDSL

    setting(:task_name, :run)
    runtime_setting(:verify_command, nil)
    runtime_setting(:command)

    def resolve_runtime_configuration
      #If there's a second troublesome command, this becomes a class-level
      #array
      if not verify_command.nil? and verify_command.name == "bundle"
        warn "Verify command is 'bundle' - this sometimes has unexpected results.  Consider BundleCommandTask"
      end

      if command.name == "bundle"
        warn "Command is 'bundle' - this sometimes has unexpected results.  Consider BundleCommandTask"
      end
    end

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
