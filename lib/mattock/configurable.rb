module Mattock
  #Handles setting options on objects it's mixed into
  #
  #Settings can have default values or be required (as opposed to defaulting to
  #nil).  Settings and their defaults are inherited (and can be overridden) by
  #subclasses.
  #
  #Mattock also includes a yard-extension that will document settings of a
  #Configurable
  #
  #@example (see ClassMethods)
  module Configurable
    class Exception < ::StandardError
    end

    class NoDefaultValue < Exception
      def initialize(field_name, klass)
        super("No default value for field #{field_name} on class #{klass.name}")
      end
    end
  end
end

require 'mattock/configurable/field-metadata'
require 'mattock/configurable/proxy-value'
require 'mattock/configurable/field-processor'
require 'mattock/configurable/class-methods'
require 'mattock/configurable/instance-methods'
require 'mattock/configurable/directory-structure'
