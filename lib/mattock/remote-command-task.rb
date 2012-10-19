require 'mattock/command-task'
module Mattock
  class RemoteCommandTask < CommandTask
    runtime_setting(:remote_server, nested(
      :address => nil,
      :user => nil
    ))
    setting(:ssh_options, [])
    nil_fields(:id_file, :free_arguments)
    runtime_setting(:remote_target)

    def resolve_runtime_configuration
      super
      self.remote_target ||= [remote_server.user, remote_server.address].compact.join('@') unless remote_server.address.nil?
    end

    def ssh_option(name, value)
      ssh_options << "\"#{name}=#{value}\""
    end

    def decorated(command_on_remote)
      fail "Need remote server for #{self.class.name}" unless remote_server.address

      raise "Empty remote command" if command_on_remote.nil?
      Mattock::WrappingChain.new do |cmd|
        cmd.add Mattock::CommandLine.new("ssh") do |cmd|
          cmd.options << "-i #{id_file}" if id_file
          unless ssh_options.empty?
            ssh_options.each do |opt|
              cmd.options << "-o #{opt}"
            end
          end
          cmd.options << remote_target
        end
        cmd.add Mattock::ShellEscaped.new(command_on_remote)
      end
    end
  end
end
