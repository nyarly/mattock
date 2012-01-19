module Mattock
  module RakeExampleGroup
    SavedEnvironmentVariables = %w{APPDATA HOME HOMEDRIVE HOMEPATH RAKE_COLUMNS RAKE_SYSTEM RAKEOPT USERPROFILE}
    DeletedEnvironmentVariables = %w{RAKE_COLUMNS RAKE_SYSTEM RAKEOPT}
    include Rake::DSL
    #include FileUtils

    class TaskManager
      include Rake::TaskManager
    end

    def self.included(mod)
      mod.class_eval do
        let! :rake do
          Rake.application = Rake::Application.new
          Rake::TaskManager.record_task_metadata = true
          RakeFileUtils.verbose_flag = false
          Rake.application
        end

        before :each do
          ARGV.clear

          @original_ENV = {}
          SavedEnvironmentVariables.each do |var|
            @original_ENV[var] = ENV[var]
          end
          DeletedEnvironmentVariables.each do |var|
            ENV.delete(var)
          end

        end

        after :each do
          SavedEnvironmentVariables.each do |var|
            ENV[var]         = @original_ENV[var]
          end

          if @original_ENV['APPDATA'].nil?
            ENV.delete 'APPDATA'
          end
        end

        before :each do
          @tempdir = File.join "/tmp", "test_mattock_#{$$}"

          @original_PWD = Dir.pwd
          FileUtils.mkdir_p @tempdir
          Dir.chdir @tempdir
        end

        after :each do
          Dir.chdir @original_PWD
          FileUtils.rm_rf @tempdir
        end
      end
    end

    module Matchers
      extend RSpec::Matchers::DSL

      define :have_task do |name|
        match do |rake|
          !rake.lookup("rake:" + name.to_s).nil?
        end
      end

      define :depend_on do |name|
        match do |task|
          task.prerequisites.include?(name)
        end
      end
    end

    include Matchers
  end
end
