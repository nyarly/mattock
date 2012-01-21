require 'ostruct'
require 'rake/tasklib'
require 'mattock/configurable'

module Mattock
  class TaskLib < Rake::TaskLib
    include Configurable

    attr_writer :namespace_name
    def self.default_namespace(name)
      setting(:namespace_name, name)
    end

    def initialize(*tasklibs)
      @tasks = []

      default_configuration(*tasklibs)

      yield self if block_given?

      resolve_configuration

      define
    end

    attr_reader :tasks

    def task(*args)
      a_task = super
      @tasks << a_task
      return a_task
    end

    def default_configuration(*tasklibs)
      setup_defaults
    end

    def resolve_configuration
      check_required
    end

    def define
    end

    def in_namespace(*tasknames)
      if tasknames.empty?
        if block_given?
          if @namespace_name.nil?
            yield
          else
            namespace @namespace_name do
              yield
            end
          end
        end
      else
        tasknames.map do |taskname|
          [@namespace_name, taskname].compact.join(":")
        end
      end
    end

    def root_task
      @namespace_name || :default
    end

    def default_namespace
      nil
    end

    def [](taskname)
      in_namespace(taskname).first
    end
  end
  Tasklib = TaskLib #Because I can never remember
end
