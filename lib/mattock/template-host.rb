require 'tilt'
require 'valise'

module Mattock
  module ValiseManager
    def default_valise(*dirs)
      Valise::Set.define do
        dirs.each do |dir|
          ro dir
        end
      end
    end

    def rel_dir(base_path = nil, up_to = nil)
      base_path ||= /(.*):\d+/.match(caller[0])[1]
      up_to ||= "lib"

      abs_path = File::expand_path(base_path)
      base_path = abs_path.split(File::Separator)
      until base_path.empty?
        unless base_path.last == up_to
          base_path.pop
        else
          break
        end
      end

      if base_path.empty?
        raise "Relative root #{up_to} not found in #{abs_path}"
      end

      return base_path
    end
    module_function :rel_dir, :default_valise
  end

  module TemplateHost
    def self.template_cache
      @template_cache ||= Tilt::Cache.new
    end

    attr_accessor :valise

    def find_template(path)
      valise.find(["templates"] + valise.unpath(path))
    end

    def template_contents(path)
      find_template(path).contents
    end

    def template_path(path)
      find_template(path).full_path
    end

    def render(path, template_options = nil)
      template = TemplateHost::template_cache.fetch(path) do
        Tilt.new(path, template_options || {}) do |tmpl|
          template_contents(tmpl.file)
        end
      end

      locals = {}
      if block_given?
        yield locals
      end

      template.render(self, locals)
    end
  end

  module TemplateTaskLib
    include TemplateHost

    def template_task(template_source, destination_path, template_options = nil)
      file template_path(template_source)
      file destination_path => template_path(template_source) do
        File::open(destination_path, "w") do |file|
          file.write(render(template_source, template_options))
        end
      end
    end
  end
end
