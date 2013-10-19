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

      def can_process(field, target)
        target.respond_to?(field.writer_method)
      end

      def to(target)
        field_names.each do |name|
          field = source.class.field_metadata(name)
          next unless can_process(field, target)
          target.__send__(field.writer_method, value(field))
        end
      end
    end

    class SettingsCopier < FieldProcessor
      def filter_attribute
        :copiable
      end

      def can_process(field, target)
        super and not( field.unset_on?(source) and field.unset_on?(target) )
      end

      def value(field)
        return field.copy_from(source)
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
