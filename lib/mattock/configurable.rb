module Mattock
  module Configurable
    RequiredField = Object.new
    class << RequiredField
      def to_s
        "<unset>"
      end

      def inspect
        to_s
      end
    end
    RequiredField.freeze

    module ClassMethods

      def default_values
        @default_values ||= {}
      end

      def set_defaults_on(instance)
        if Configurable > superclass
          superclass.set_defaults_on(instance)
        end
        default_values.each_pair do |name,value|
          instance.__send__("#{name}=", value)
          if Configurable === value
            value.class.set_defaults_on(value)
          end
        end
      end

      def missing_required_fields_on(instance)
        missing = []
        if Configurable > superclass
          missing = superclass.missing_required_fields_on(instance)
        end
        default_values.each_pair do |name,value|
          set_value = instance.__send__(name)
          if value == RequiredField and set_value == RequiredField
            missing << name
            next
          end
          if Configurable === set_value
            missing += set_value.class.missing_required_fields_on(set_value).map do |field|
              [name, field].join(".")
            end
          end
        end
        return missing
      end

      def nested(hash=nil)
        obj = Class.new(Struct).new
        obj.settings(hash || {})
        return obj
      end

      def nil_fields(*names)
        names.each do |name|
          setting(name, nil)
        end
      end
      alias nil_field nil_fields

      def required_fields(*names)
        names.each do |name|
          setting(name)
        end
      end
      alias required_field required_fields

      def setting(name, default_value = RequiredField)
        name = name.to_sym
        attr_accessor(name)
        if default_values.has_key?(name) and default_values[name] != default_value
          warn "Changing default value of #{self.name}##{name} from #{default_values[name].inspect} to #{default_value.inspect}"
        end
        default_values[name] = default_value
      end

      def settings(hash)
        hash.each_pair do |name, value|
          setting(name, value)
        end
        return self
      end
    end

    def self.included(mod)
      mod.extend ClassMethods
    end

    def setup_defaults
      self.class.set_defaults_on(self)
      self
    end

    def check_required
      missing = self.class.missing_required_fields_on(self)
      unless missing.empty?
        raise "Required field#{missing.length > 1 ? "s" : ""} #{missing.join(", ")} unset on #{self.inspect}"
      end
      self
    end

    def setting(name, default_value = nil)
      self.class.setting(name, default_value)
      instance_variable_set("@#{name}", default_value)
    end

    def settings(hash)
      hash.each_pair do |name, value|
        setting(name, value)
      end
      return self
    end

    def required_fields(*names)
      self.class.required_fields(*names)
      self
    end
    alias required_field required_fields

    class Struct
      include Configurable
    end
  end
end
