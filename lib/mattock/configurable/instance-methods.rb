require 'mattock/configurable/directory-structure'

module Mattock
  module Configurable
    def initialize_copy(original)
      original.copy_settings_to(self)
    end

    def copy_settings
      SettingsCopier.new(self)
    end

    def copy_settings_to(other)
      copy_settings.to(other)
      self
    end

    def proxy_settings
      SettingsProxier.new(self)
    end

    def proxy_settings_to(other)
      proxy_settings.to(other)
    end

    def to_hash
      self.class.to_hash(self)
    end

    def from_hash(hash)
      self.class.from_hash(self, hash)
    end

    def unset_defaults_guard
      raise "Tried to check required settings before running setup_defaults"
    end

    #Call during initialize to set default values on settings - if you're using
    #Configurable outside of Mattock, be sure this gets called.
    def setup_defaults
      def self.unset_defaults_guard
      end

      self.class.set_defaults_on(self)
      self
    end

    #Checks that all required fields have be set, otherwise raises an error
    #@raise RuntimeError if any required fields are unset
    def check_required
      unset_defaults_guard
      missing = self.class.missing_required_fields_on(self)
      unless missing.empty?
        raise "Required field#{missing.length > 1 ? "s" : ""} #{missing.map{|field| field.to_s.inspect}.join(", ")} unset on #{self.inspect}"
      end
      self
    end

    def proxy_value
      ProxyDecorator.new(self)
    end

    #XXX deprecate
    def unset?(value)
      warn "#unset? is deprecated - use field_unset? instead"
      value.nil?
    end

    def field_unset?(name)
      self.class.field_metadata(name).unset_on?(self)
    end

    #Requires that a named field be set
    def fail_unless_set(name)
      if field_unset?(name)
        raise "Assertion failed: Field #{name} unset"
      end
      true
    end
    alias fail_if_unset fail_unless_set

    class Struct
      include Configurable
      include Configurable::DirectoryStructure
    end
  end
end
