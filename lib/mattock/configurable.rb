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
    class FieldMetadata
      attr_accessor :name, :default_value

      DEFAULT_PROPERTIES = {
        :copiable => true,
        :proxiable => true,
        :required => false,
        :runtime => false,
        :defaulting => true,
      }
      def initialize(name, value)
        @name = name
        @default_value = value
        @properties = DEFAULT_PROPERTIES.clone
      end

      def inspect
        set_props = DEFAULT_PROPERTIES.keys.find_all do |prop|
          @properties[prop]
        end
        "Field: #{name}: #{default_value.inspect} #{set_props.inspect}"
      end

      def validate_property_name(name)
        unless DEFAULT_PROPERTIES.has_key?(name)
          raise "Invalid field property #{name.inspect} - valid are: #{DEFAULT_PROPERTIES.keys.inspect}"
        end
      end

      def is?(property)
        validate_property_name(property)
        @properties[property]
      end

      def is_not?(property)
        validate_property_name(property)
        !@properties[property]
      end
      alias isnt? is_not?

      def is(property)
        validate_property_name(property)
        @properties[property] = true
        self
      end

      def is_not(property)
        validate_property_name(property)
        @properties[property] = false
        self
      end
      alias isnt is_not

      def ivar_name
        "@#{name}"
      end

      def writer_method
        "#{name}="
      end

      def reader_method
        name
      end

      def immediate_value_on(instance)
        instance.instance_variable_get(ivar_name)
      end

      def value_on(instance)
        value = immediate_value_on(instance)
        if ProxyValue === value
          value.field.value_on(value.source)
        else
          value
        end
      end

      def set_on?(instance)
        return false unless instance.instance_variable_defined?(ivar_name)
        value = immediate_value_on(instance)
        if name == :destination_path
        end
        if ProxyValue === value
          value.field.set_on?(value.source)
        else
          true
        end
      end

      def unset_on?(instance)
        !set_on?(instance)
      end

      def missing_on?(instance)
        return false unless is?(:required)
        if instance.respond_to?(:runtime?) and !instance.runtime?
          return runtime_missing_on?(instance)
        else
          return !set_on?(instance)
        end
      end

      def runtime_missing_on?(instance)
        return false if is?(:runtime)
        return true unless instance.instance_variable_defined?(ivar_name)
        value = immediate_value_on(instance)
        if ProxyValue === value
          value.field.runtime_missing_on?(value.source)
        else
          false
        end
      end
    end

    class ProxyValue
      def initialize(source, field)
        @source, @field = source, field
      end
      attr_reader :source, :field

      def inspect
        "#{self.class.name.split(':').last}: #{value}"
      end
    end

    class ProxyDecorator
      def initialize(configurable)
        @configurable = configurable
      end

      def method_missing(name, *args, &block)
        super unless block.nil? and args.empty?
        super unless @configurable.respond_to?(name)
        return ProxyValue.new(@configurable, @configurable.class.field_metadata(name))
      end
    end

    class FieldProcessor
      def initialize(source)
        @source = source
        @field_names = filter(source.class.field_names)
      end
      attr_accessor :field_names
      attr_reader :source

      def filter_attribute
        raise NotImplementedError
      end

      def filter(field_names)
        field_names.find_all do |name|
          source.class.field_metadata(name).is?(filter_attribute)
        end
      end

      def value(field)
        source.__send__(field.reader_method)
      end

      def to(target)
        field_names.each do |name|
          field = source.class.field_metadata(name)
          next unless target.respond_to?(field.writer_method)
          target.__send__(field.writer_method, value(field))
        end
      end
    end

    class SettingsCopier < FieldProcessor
      def filter_attribute
        :copiable
      end

      def value(field)
        field.immediate_value_on(source)
      end
    end

    class SettingsProxier < FieldProcessor
      def filter_attribute
        :proxiable
      end

      def value(field)
        ProxyValue.new(source, field)
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
        @default_values ||= []
      end

      def field_names
        names = default_values.map{|field| field.name}
        if Configurable > superclass
          names | superclass.field_names
        else
          names
        end
      end

      def field_metadata(name)
        field = default_values.find{|field| field.name == name}
        if field.nil? and Configurable > superclass
          superclass.field_metadata(name)
        else
          field
        end
      end

      #Creates an anonymous Configurable - useful in complex setups for nested
      #settings
      #@example SSH options
      #  setting :ssh => nested(:username => "me", :password => nil)
      def nested(hash=nil, &block)
        nested = Class.new(Struct)
        nested.settings(hash || {})
        if block_given?
          nested.instance_eval(&block)
        end
        return nested
      end

      #Quick list of setting fields with a default value of nil.  Useful
      #especially with {CascadingDefinition#resolve_configuration}
      def nil_fields(*names)
        names.each do |name|
          setting(name, nil)
        end
        self
      end
      alias nil_field nil_fields

      #List fields with no default for with a value must be set before
      #definition.
      def required_fields(*names)
        names.each do |name|
          setting(name)
        end
        self
      end
      alias required_field required_fields

      RequiredField = Object.new.freeze

      #Defines a setting on this class - much like a attr_accessible call, but
      #allows for defaults and required settings
      def setting(name, default_value = RequiredField)
        name = name.to_sym
        metadata =
          if default_value == RequiredField
            FieldMetadata.new(name, nil).is(:required).isnt(:defaulting)
          else
            FieldMetadata.new(name, default_value)
          end

        attr_writer(name)
        define_method(metadata.reader_method) do
          value = metadata.value_on(self)
        end

        if existing = default_values.find{|field| field.name == name} and existing.default_value != default_value
          source_line = caller.drop_while{|line| /#{__FILE__}/ =~ line}.first
          warn "Changing default value of #{self.name}##{name} from #{existing.default_value.inspect} to #{default_value.inspect}"
            "  (at: #{source_line})"
        end
        default_values << metadata
        metadata
      end

      def runtime_required_fields(*names)
        names.each do |name|
          runtime_setting(name)
        end
        self
      end
      alias runtime_required_field runtime_required_fields

      def runtime_setting(name, default_value = RequiredField)
        setting(name, default_value).is(:runtime)
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

      def set_defaults_on(instance)
        if Configurable > superclass
          superclass.set_defaults_on(instance)
        end
        default_values.each do |field|
          next unless field.is? :defaulting
          value = field.default_value
          if Module === value and Configurable > value
            value = value.new
            value.class.set_defaults_on(value)
          end
          instance.__send__(field.writer_method, value)
        end
      end

      def missing_required_fields_on(instance)
        missing = []
        if Configurable > superclass
          missing = superclass.missing_required_fields_on(instance)
        end
        default_values.each do |field|
          if field.missing_on?(instance)
            missing << field.name
          else
            set_value = instance.__send__(field.reader_method)
            if Configurable === set_value
              missing += set_value.class.missing_required_fields_on(set_value).map do |field|
                [name, field].join(".")
              end
            end
          end
        end
        return missing
      end

      def copy_settings(from, to, &block)
        if Configurable > superclass
          superclass.copy_settings(from, to, &block)
        end
        default_values.each do |field|
          begin
            value =
              if block_given?
                yield(from, field)
              else
                from.__send__(field.reader_method)
              end
            if Configurable === value
              value = value.clone
            end
            to.__send__(field.writer_method, value)
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
        hash.merge( Hash[default_values.map{|field|
          begin
            value = obj.__send__(field.reader_method)
            value =
              case value
              when Configurable
                value.to_hash
              else
                value
              end
            [field.name, value]
          rescue NoMethodError
          end
        }])
      end


      def included(mod)
        mod.extend ClassMethods
      end
    end

    extend ClassMethods

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
      value.nil?
    end

    def field_unset?(name)
      self.class.field_metadata(name).unset_on?(self)
    end

    def fail_unless_set(name)
      if self.class.field_metadata(name).unset_on?(self)
        raise "Assertion failed: Field #{name} unset"
      end
      true
    end

    class Struct
      include Configurable
    end
  end
end
