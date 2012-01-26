require 'mattock/configurable'

module Mattock
  module CascadingDefinition
    include Configurable

    def initialize(*tasklibs)
      setup_defaults
      default_configuration(*tasklibs)

      yield self if block_given?

      resolve_configuration
      confirm_configuration

      define
    end

    def default_configuration(*tasklibs)
    end

    def resolve_configuration
    end

    def confirm_configuration
      check_required
    end

    def define
    end
  end
end
