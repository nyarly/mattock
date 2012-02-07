require 'mattock/command-task'
module Mattock
  class RemoteCommandTask < CommandTask
    setting(:remote_server, nested(
      :address => "localhost",
      :user => nil
    ))
    setting(:ssh_options, [])
    nil_fields(:id_file, :free_arguments)

    def decorated(command_on_remote)
      fail "Need remote server for #{self.class.name}" unless remote_server.address

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
end
