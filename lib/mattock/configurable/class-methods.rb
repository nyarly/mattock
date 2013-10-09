module Mattock
  module Configurable
    RequiredField = Object.new.freeze

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
      def inspect_instance(instance, indent="")
        field_names.map do |name|
          meta = field_metadata(name)
          "#{indent}#{meta.inspect_on(instance, indent * 2)}"
        end.join("\n")
      end

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

      #@raises NoDefaultValue
      def default_value_for(name)
        field = field_metadata(name)
        raise NoDefaultValue.new(name,self) unless field.is?(:defaulting)
        return field.default_value
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
            warn "Changing default value of #{self.name}##{name} from #{existing.default_value.inspect} to #{default_value.inspect} (at: #{source_line})"
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
              missing += set_value.class.missing_required_fields_on(set_value).map do |sub_field|
                [field.name, sub_field].join(".")
              end
            end
          end
        end
        return missing
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
  end
end
