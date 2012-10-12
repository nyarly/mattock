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

      def initialize(name, value)
        @name = name
        @default_value = value
        @copiable = true
        @proxiable = true
      end

      def copiable?
        !!@copiable
      end

      def dont_copy
        @copiable = false
        self
      end

      def proxiable?
        !!@proxiable
      end

      def dont_proxy
        @proxiable = false
        self
      end

      def writer_method
        "#{name}="
      end

      def reader_method
        name
      end
    end

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
        @instance ||= self.new
      end
    end

    class RuntimeRequiredField < RequiredField
      def to_s
        "<unset:runtime>"
      end

      def required_on?(host)
        if host.respond_to?(:runtime?) and !host.runtime?
          return false
        else
          return true
        end
      end
    end

    class DecoratedValue
      def value
        begin
          value = real_value
        end while DecoratedValue === value
        value
      end

      def inspect
        "#{self.class.name.split(':').last}: #{value}"
      end
    end

    class ProxyValue < DecoratedValue
      def initialize(source, field)
        @source, @field = source, field
      end

      def real_value
        @source.__send__(@field.reader_method)
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

      def filter(field_names)
        field_names.find_all do |name|
          source.class.field_metadata(name).copiable?
        end
      end

      def value(field)
        source.__send__(field.reader_method)
      end

      def to(target)
        field_names.each do |name|
          field = source.class.field_metadata(name)
          target.__send__(field.writer_method, value(field))
        end
      end
    end

    class SettingsCopier < FieldProcessor
      def filter(field_names)
        field_names.find_all do |name|
          source.class.field_metadata(name).copiable?
        end
      end

      def value(field)
        source.__send__(field.reader_method)
      end
    end

    class SettingsProxier < FieldProcessor
      def filter(field_names)
        field_names.find_all do |name|
          source.class.field_metadata(name).proxiable?
        end
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
        metadata = FieldMetadata.new(name, default_value)

        attr_writer(name)
        define_method(metadata.reader_method) do
          value = instance_variable_get("@#{name}")
          if DecoratedValue === value
            value = value.value
          end
          value
        end

        if existing = default_values.find{|field| field.name == name} and existing.default_value != default_value
          warn "Changing default value of #{self.name}##{name} from #{default_values[name].inspect} to #{default_value.inspect}"
          source_line = caller.drop_while{|line| /#{__FILE__}/ =~ line}.first
          warn "  (at: #{source_line})"
        end
        default_values << metadata
        metadata
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

      def set_defaults_on(instance)
        if Configurable > superclass
          superclass.set_defaults_on(instance)
        end
        default_values.each do |field|
          instance.__send__(field.writer_method, field.default_value)
          if Configurable === (value = field.default_value)
            value.class.set_defaults_on(value)
          end
        end
      end

      def missing_required_fields_on(instance)
        missing = []
        if Configurable > superclass
          missing = superclass.missing_required_fields_on(instance)
        end
        default_values.each do |field|
          set_value = instance.__send__(field.reader_method)

          case set_value
          when RequiredField
            missing << name if set_value.required_on?(instance)
          when Configurable
            missing += set_value.class.missing_required_fields_on(set_value).map do |field|
              [name, field].join(".")
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

    def unset?(value)
      RequiredField === value
    end

    def fail_unless_set(name)
      if unset?(__send__(name))
        raise "Required field #{name} unset"
      end
      true
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
