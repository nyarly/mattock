require 'valise'

module Mattock
  #Configuration for the set of Tasklibs - useful for when there are settings
  #that shouldn't be part of the Rakefile, or are specific to a particular
  #environment rather than a set of tasks - e.g. specific to each developer's
  #laptop or the server.
  #
  #@example How to Use:
  #  module CoolTasks
  #    def config
  #      @config ||= Mattock::ConfigurationStore.new("cool_tasks")
  #    end
  #
  #    def preferences
  #      config.loaded["preferences.yaml"]
  #    end
  #
  #    class AwesomeLib < Mattock::Tasklib
  #      setting :level, CoolTasks.preferences[:level]
  #    end
  #  end
  #
  #@example In Rakefile
  #  CoolTasks.config.register_search_path(__FILE__)
  #
  #Having done that, any preferences.yaml file in any of several directories
  #will get merged into a single hash and be available as CoolTasks.preferences
  #
  #The search path will look like:
  #
  # * /etc/mattock
  # * /etc/cool_tasks
  # * /usr/share/mattock
  # * /usr/share/cool_tasks
  # * ~/.mattock
  # * ~/.cool_tasks
  # * <Rakefile_dir>/.cool_tasks
  #
  # Each file found will be merged into the running hash, so preferences.yaml
  # in the project dir will be able to override everything.
  #
  #Last bonus: any file can be added into that search path, and the 'closest'
  #one will be found and returned by config.loaded[filename]
  class ConfigurationStore
    #@param [String] app_name The path component to represent this gem -
    #  consider downcasing your root module
    #@param [String] library_default_dir If present, a directory containing
    #  default files that come in the gem
    def initialize(app_name, library_default_dir = nil)
      @app_name = app_name
      @valise = Valise::Set.define do
        rw "~/.#{app_name}"
        rw "~/.mattock/#{app_name}"
        rw "~/.mattock"

        rw "/usr/share/#{app_name}"
        rw "/usr/share/mattock/#{app_name}"
        rw "/usr/share/mattock"

        rw "/etc/#{app_name}"
        rw "/etc/mattock/#{app_name}"
        rw "/etc/mattock"

        ro library_default_dir unless library_default_dir.nil?
        ro from_here("default_configuration")

        handle "preferences.yaml", :yaml, :hash_merge
      end

      @loaded ||= Hash.new{|h,k| h[k] = @valise.find(k).contents}
    end

    attr_reader :loaded, :valise

    #Add special file handling for a particular file
    def register_file(name, type, merge)
      @valise.add_handler(name, type, merge)
    end

    #Add a search path to look for configuration files
    def register_search_path(from_file)
      directory = File::expand_path("../.#{@app_name}", from_file)
      @valise.prepend_search_root(Valise::SearchRoot.new(directory))
      loaded.clear
    end

    def user_preferences
      loaded["preferences.yaml"]
    end
  end
end
