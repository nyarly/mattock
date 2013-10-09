require 'mattock/command-task'
module Mattock
  module Rake
    class RemoteCommandTask < CommandTask
      setting(:remote_server, nested{
        setting :address
        setting :port, 22
        setting :user, nil
      })

      setting(:ssh_options, [])
      setting(:verbose, 0)
      nil_fields(:id_file, :free_arguments)

      def ssh_option(name, value)
        ssh_options << "\"#{name}=#{value}\""
      end

      def decorated(command_on_remote)
        fail "Need remote server for #{self.class.name}" unless remote_server.address

        raise "Empty remote command" if command_on_remote.nil?
        Mattock::WrappingChain.new do |cmd|
          cmd.add Mattock::CommandLine.new("ssh") do |cmd|
            cmd.options << "-i #{id_file}" if id_file
            cmd.options << "-l #{remote_server.user}" unless remote_server.user.nil?
            cmd.options << remote_server.address
            cmd.options << "-p #{remote_server.port}" #ok
            cmd.options << "-n"
            cmd.options << "-#{'v'*verbose}" if verbose > 0
            unless ssh_options.empty?
              ssh_options.each do |opt|
                cmd.options << "-o #{opt}"
              end
            end
          end
          cmd.add Mattock::ShellEscaped.new(command_on_remote)
        end
      end
    end
  end

  class RemoteCommandTask < DeprecatedTaskAPI
    def target_class; Rake::RemoteCommandTask; end
  end
end
