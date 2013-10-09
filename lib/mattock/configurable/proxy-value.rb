module Mattock
  module Configurable
    class ProxyValue
      def initialize(source, field)
        @source, @field = source, field
      end
      attr_reader :source, :field

      def inspect
        "#{self.class.name.split(':').last}: #{source.class.name}.#{field.inspect}"
      end
    end

    class ProxyDecorator
      def initialize(configurable)
        @configurable = configurable
      end

      def method_missing(name, *args, &block)
        unless block.nil? and args.empty?
          raise NoMethodError, "method `#{name}' not defined with arguments or block when proxied"
        end
        unless @configurable.respond_to?(name)
          raise NoMethodError, "cannot proxy `#{name}' - undefined on #{@configurable}"
        end
        return ProxyValue.new(@configurable, @configurable.class.field_metadata(name))
      end
    end
  end
end
