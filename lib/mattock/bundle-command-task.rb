require 'mattock/command-task'

module Mattock
  class BundleCommandTask < CommandTask
    class BundleEnvCleaner < CommandLine
      def initialize(original)
        @executable = original.executable
        @options = original.options
        @redirections = original.redirections
        @env = original.env
      end

      def run
        if defined? Bundler
          Bundler.with_original_env do
            super
          end
        else
          super
        end
      end
    end

    def decorated(command)
      BundleEnvCleaner.new(command)
    end
  end
end
