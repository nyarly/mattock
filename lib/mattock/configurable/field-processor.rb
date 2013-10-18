module Mattock
  module Configurable
    class FieldProcessor
      def initialize(source)
        @source = source
        @field_names = filter(source.class.field_names)
      end
      attr_accessor :field_names
      attr_reader :source

      def filter(field_names)
        field_names.find_all do |name|
          source.class.field_metadata(name).is?(filter_attribute)
        end
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
        value = field.immediate_value_on(source)
        case value
        when Numeric, NilClass, TrueClass, FalseClass
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
    end

    class SettingsProxier < FieldProcessor
      def filter_attribute
        :proxiable
      end

      def value(field)
        ProxyValue.new(source, field)
      end
    end
  end
end
