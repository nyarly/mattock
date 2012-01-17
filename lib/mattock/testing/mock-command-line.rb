require 'mattock/command_line'

module Mattock
  module MockCommandLine
    module ClassMethods
      def stub_commands
        @stub_commands ||= {}
      end

      def stub_commands=(hash)
        @stub_commands.merge!(hash)
      end

      def mock_commands
        @mock_commands ||= []
      end

      def mock_commands=(hash)
        stub_commands = stub_commands.merge(hash)
        @mock_commands = mock_commands | hash.keys
      end
    end

    def run
      if self.class.stub_commands.has_key?(name)
        return self.class.stub_commands[name]
      else
        raise "Unexpected command: #{name}"
      end
    end
  end


  module CommandLine
    def self.mock!(commands = nil)
      extend MockCommandLine::ClassMethods
      include MockCommandLine
      unless commands.nil?
        stub_commands = commands
      end
    end
  end
end
