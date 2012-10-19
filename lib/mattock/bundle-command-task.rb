require 'mattock/command-task'

module Mattock
  class BundleCommandTask < CommandTask
    class BundleEnvCleaner < CommandLine
      def initialize(original)
        @original = original
      end

      def run
        original_env = ENV.to_hash
        if defined? Bundler
          %w{
            BUNDLER_EDITOR
            BUNDLE_APP_CONFIG
            BUNDLE_BIN_PATH
            BUNDLE_CONFIG
            BUNDLE_PATH
            BUNDLE_SPEC_RUN
            DEBUG
            DEBUG_RESOLVER
            EDITOR
            GEM_HOME
            GEM_PATH
            MANPAGER
            PAGER
            PATH
            RB_USER_INSTALL
            RUBYOPT
            VISUAL
          }.each do |bundler_varname|
            begin
              ENV[bundler_varname] = Bundler::ORIGINAL_ENV.fetch(bundler_varname)
            rescue KeyError
              ENV.delete(bundler_varname)
            end
          end
        end
        %w{
          BUNDLE_GEMFILE
        }

        @original.run
      ensure
        ENV.replace(original_env)
      end
    end

    def decorated(command)
      BundleEnvCleaner.new(command)
    end
  end
end
