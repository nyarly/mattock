require 'mattock/command-line'

module Mattock
  class CommandLine
    @@commands = []
    alias original_execute execute

    def execute
      result = original_execute
      @@commands << [command, result]
      return result
    end

    class << self
      attr_accessor :command_recording_path

      def command_recording_path
        @command_recording_path ||= ENV['MATTOCK_CMDREC']
      end

      def emit_recording
        io = $stderr
        if command_recording_path
          io = File.open(command_recording_path, "w")
        else
          io.puts "Set MATTOCK_CMDREC to write to a path"
        end
        @@commands.each do |pair|
          io.puts "[/#{pair[0]}/, #{[pair[1].exit_code, pair[1].streams].inspect}]"
        end
      end
    end
  end
end

at_exit do
  Mattock::CommandLine.emit_recording
end
