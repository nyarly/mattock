require 'tilt'
require 'valise'

module Mattock
  module ValiseManager
    def default_valise(*dirs)
      Valise::read_only(*dirs)
    end

    def rel_dir(base_path = nil, up_to = nil)
      Valise::Unpath.up_to(up_to, base_path)
    end
    module_function :rel_dir, :default_valise
    public :rel_dir, :default_valise
  end

  #@deprecated Use {Valise::Set#templates} instead
  module TemplateHost
    attr_accessor :valise

    def templates_are_in(valise)
      self.valise = valise.templates
    end

    #XXX Better to let clients stem or subset
    def find_template(path)
      valise.find(path)
    end

    def template(path)
      find_template(path).contents
    end

    def template_path(path)
      find_template(path).full_path
    end

    def render(path)
      locals = {}
      if block_given?
        yield locals
      end

      template(path).render(self, locals)
    end
  end

  #@deprecated Use {Valise::Set#templates} instead
  module TemplateTaskLib
    include TemplateHost

    #@deprecated Use {Valise::Set#templates} instead
    def template_task(template_source, destination_path, template_options = nil)
      unless template_options.nil?
        valise.add_serialization_handler(template_source, :tilt, :template_options => template_options)
      end

      file template_path(template_source)
      file destination_path => template_path(template_source) do
        File::open(destination_path, "w") do |file|
          file.write(render(template_source))
        end
      end
    end
  end
end
