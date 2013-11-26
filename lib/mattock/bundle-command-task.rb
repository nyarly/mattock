require 'mattock/command-task'

module Mattock
  class BundleCommandTask < Rake::CommandTask
    def cleaned_env
      env = {}
      if defined? Bundler
        %w{
          BUNDLER_EDITOR
          BUNDLE_APP_CONFIG
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
          bundle_bin
          bundle_dir
        }.each do |bundler_varname|
          next if ENV[bundler_varname] == Bundler::ORIGINAL_ENV[bundler_varname]
          env[bundler_varname] = Bundler::ORIGINAL_ENV[bundler_varname]
        end
        %w{
          bundle_bin
          bundle_dir
          BUNDLE_BIN_PATH
          BUNDLE_GEMFILE
        }.each do |bundler_varname|
          env[bundler_varname] = nil
        end
      end
      env
    end

    def decorated(command)
      command.command_environment.merge!(cleaned_env)
      command
    end
  end
end
