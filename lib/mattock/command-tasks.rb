require 'mattock/command-line'

module Mattock
  class CommandTask < TaskLib
    setting(:task_name, :run)

    def command_task
      @command_task ||=
        begin
          task task_name do
            do_this = command
            do_this.run
            do_this.must_succeed!
          end
        end
    end

    def define
      in_namespace do
        command_task
      end
    end
  end

  class RemoteCommandTask < CommandTask
    setting(:remote_server, nested(
      :address => nil,
      :user => nil
    ))
    setting(:ssh_options, [])
    setting(:remote_command)
    nil_fields(:id_file, :free_arguments)

    def command(command_on_remote = nil)
      fail "Need remote server for #{self.class.name}" unless remote_server.address

      command_on_remote ||= remote_command

      raise "Empty remote command" if command_on_remote.nil?
      Mattock::WrappingChain.new do |cmd|
        cmd.add Mattock::CommandLine.new("ssh") do |cmd|
          cmd.options << "-u #{remote_server.user}" if remote_server.user
          cmd.options << "-i #{id_file}" if id_file
          unless ssh_options.empty?
            ssh_options.each do |opt|
              cmd.options "-o #{opt}"
            end
          end
          cmd.options << remote_server.address
        end
        cmd.add Mattock::ShellEscaped.new(command_on_remote)
      end
    end
  end

  class VerifiableCommandTask < RemoteCommandTask
    setting(:verify_command, nil)

    def verify_command
      if @verify_command.respond_to?(:call)
        @verify_command = @verify_command.call
      end
      @verify_command
    end

    def define
      super

      definer = self
      (class << command_task; self; end).instance_eval do
        define_method :needed? do
          !definer.command(definer.verify_command).succeeds?
        end
      end
    end
  end
end
