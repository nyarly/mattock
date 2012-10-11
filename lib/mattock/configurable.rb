module Mattock
  #Handles setting options on objects its mixed into
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
    class RequiredField
      def to_s
        "<unset>"
      end

      def inspect
        to_s
      end

      def required_on?(host)
        true
      end

      def self.instance
        @instane ||= self.new
      end
    end

    class RuntimeRequiredField < RequiredField
      def required_on?(host)
        if host.responds_to?(:runtime?) and !host.runtime?
          return false
        else
          return true
        end
      end
    end

    class DecoratedValue
      def initialize(value)
        @value = value
      end

      def value
        begin
          value = real_value
        end while DecoratedValue === value
        value
      end

      def real_value
        @value
      end
    end

    class ProxyValue < DecoratedValue
      def initialize(source, name)
        @source, @name = source, name
      end

      def real_value
        @source.__send__(@name)
      end
    end

    class ProxyDecorator
      def initialize(configurable)
        @configurable = configurable
      end

      def method_missing(name, *args, &block)
        super unless block.nil? and args.empty?
        super unless @configurable.responds_to?(name)
        return ProxyValue.new(@configurable, name)
      end
    end

    #Describes class level DSL & machinery for working with configuration
    #managment.
    #
    #@example
    #    class ConfExample
    #      include Configurable
    #
    #      setting :foo
    #      settings :bar => 1, :baz => 3
    #      nil_fields :hoo, :ha, :harum
    #      required_fields :must
    #
    #      def initialize
    #        setup_defaults
    #      end
    #    end
    #
    #    ce = ConfExample.new
    #    ce.bar #=> 1
    #    ce.hoo #=> nil
    #    ce.hoo = "hallo"
    #    ce.check_required #=> raises error because :must and :foo aren't set
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
          if RequiredField === set_value and set_value.required_on?(instance)
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

      def copy_settings(from, to)
        if Configurable > superclass
          superclass.copy_settings(from, to)
        end
        default_values.keys.each do |field|
          begin
            value =
              if block_given?
                yield(from, field)
              else
                from.__send__(field)
              end
            to.__send__("#{field}=", value)
          rescue NoMethodError
            #shrug it off
          end
        end
      end

      def to_hash(obj)
        hash = if Configurable > superclass
                 superclass.to_hash(obj)
               else
                 {}
               end
        hash.merge( Hash[default_values.keys.zip(default_values.keys.map{|key|
          begin
            obj.__send__(key)
          rescue NoMethodError
          end
        }).to_a])
      end

      #Creates an anonymous Configurable - useful in complex setups for nested
      #settings
      #@example SSH options
      #  setting :ssh => nested(:username => "me", :password => nil)
      def nested(hash=nil)
        obj = Class.new(Struct).new
        obj.settings(hash || {})
        return obj
      end

      #Quick list of setting fields with a default value of nil.  Useful
      #especially with {CascadingDefinition#resolve_configuration}
      def nil_fields(*names)
        names.each do |name|
          setting(name, nil)
        end
      end
      alias nil_field nil_fields

      #List fields with no default for with a value must be set before
      #definition.
      def required_fields(*names)
        names.each do |name|
          setting(name)
        end
      end
      alias required_field required_fields

      #Defines a setting on this class - much like a attr_accessible call, but
      #allows for defaults and required settings
      def setting(name, default_value = RequiredField.instance)
        name = name.to_sym
        attr_writer(name)
        define_method(name) do
          value = instance_variable_get("@#{name}")
          if DecoratedValue === value
            value = value.value
          end
          value
        end
        if default_values.has_key?(name) and default_values[name] != default_value
          warn "Changing default value of #{self.name}##{name} from #{default_values[name].inspect} to #{default_value.inspect}"
        end
        default_values[name] = default_value
      end

      def runtime_required_fields(*names)
        names.each do |name|
          setting(name, RuntimeRequiredField.instance)
        end
      end
      alias runtime_required_field runtime_required_fields

      def runtime_setting(name, default_value = RuntimeRequiredField.instance)
        setting(name, default_value)
      end

      #@param [Hash] hash Pairs of name/value to be converted into
      #  setting/default
      def settings(hash)
        hash.each_pair do |name, value|
          setting(name, value)
        end
        return self
      end
      alias runtime_settings settings

      def included(mod)
        mod.extend ClassMethods
      end
    end

    extend ClassMethods

    def copy_settings_to(other)
      self.class.copy_settings(self, other)
      self
    end

    def copy_proxy_settings_to(other)
      self.class.copy_settings(self, other) do |source, name|
        ProxyValue.new(source, name)
      end
    end

    def to_hash
      self.class.to_hash(self)
    end

    #Call during initialize to set default values on settings - if you're using
    #Configurable outside of Mattock, be sure this gets called.
    def setup_defaults
      self.class.set_defaults_on(self)
      self
    end

    #Checks that all required fields have be set, otherwise raises an error
    #@raise RuntimeError if any required fields are unset
    def check_required
      missing = self.class.missing_required_fields_on(self)
      unless missing.empty?
        raise "Required field#{missing.length > 1 ? "s" : ""} #{missing.map{|field| field.to_s.inspect}.join(", ")} unset on #{self.inspect}"
      end
      self
    end

    def proxy_value
      ProxyDecorator.new(selfj)
    end

    def unset?(value)
      RequiredField === value
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

    def nil_fields(*names)
      self.class.nil_fields(*names)
      self
    end
    alias nil_field nil_fields

    class Struct
      include Configurable
    end
  end
end
