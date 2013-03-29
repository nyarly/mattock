require 'mattock/task'
require 'mattock/command-line'

module Mattock
  module CommandTaskMixin
    include CommandLineDSL

    def self.included(sub)
      sub.extend CommandLineDSL
      sub.runtime_setting(:verify_command, nil)
      sub.runtime_setting(:command)
    end

    def resolve_runtime_configuration
      super
      #If there's a second troublesome command, this becomes a class-level
      #array
      if not verify_command.nil? and verify_command.name == "bundle"
        unless BundleCommandTask === self
          warn "Verify command is 'bundle' - this sometimes has unexpected results.  Consider BundleCommandTask"
        end
      end

      if command.name == "bundle"
        unless BundleCommandTask === self
          warn "Command is 'bundle' - this sometimes has unexpected results.  Consider BundleCommandTask"
        end
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

    def action(args)
      decorated(command).must_succeed!
    end

    def needed?
      finalize_configuration
      if verify_command.nil?
        super
      else
        !decorated(verify_command).succeeds?
      end
    end
  end

  class Rake::CommandTask < Rake::Task
    include CommandTaskMixin
    setting :task_name, :run
  end

  class Rake::FileCommandTask < Rake::FileTask
    include CommandTaskMixin

    setting :target_path

    def resolve_configuration
      super
      self.target_path ||= task_name
    end
  end

  class CommandTask < DeprecatedTaskAPI
    def target_class; Rake::CommandTask; end
  end

  class FileCommandTask < DeprecatedTaskAPI
    def target_class; Rake::FileCommandTask; end
  end
end
