module Mattock
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

      def inspect_on(instance, indent=nil)
        set_props = DEFAULT_PROPERTIES.keys.find_all do |prop|
          @properties[prop]
        end
        "Field: #{name}: #{value_on(instance).inspect} \n#{indent||""}(default: #{default_value.inspect} immediate: #{immediate_value_on(instance).inspect}) #{set_props.inspect}"
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

      def copy_from(instance)
        return if unset_on?(instance)
        copy_value(immediate_value_on(instance))
      end

      def build_default_value
        if Module === @default_value and Configurable > @default_value
          value = @default_value.new
          value.class.set_defaults_on(value)
          value
        else
          copy_value(@default_value)
        end
      end

      def copy_value(value)
        case value
        when Symbol, Numeric, NilClass, TrueClass, FalseClass
          value
        else
          if value.class == BasicObject
            value
          elsif value.respond_to?(:dup)
            value.dup
          elsif value.respond_to?(:clone)
            value.clone
          else
            value
          end
        end
      end

      def immediate_value_on(instance)
        instance.instance_variable_get(ivar_name)
        #instance.__send__(reader_method)
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
        return true unless instance.__send__(reader_method).nil?
        return false unless instance.instance_variable_defined?(ivar_name)
        value = immediate_value_on(instance)
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
  end
end
