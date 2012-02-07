YARD::Templates::Engine.register_template_path File::expand_path("../../../yard_templates", __FILE__)

module Mattock
  module YARDExtensions
    class SettingHandler < YARD::Handlers::Ruby::Base
      include YARD::Parser::Ruby

      handles method_call(:setting)
      namespace_only

      def extract_name(obj)
        case obj.type
        when :symbol_literal
          obj.jump(:ident, :op, :kw, :const)[0]
        when :string_literal
          obj.jump(:tstring_content)[0]
        else
          raise YARD::Parser::UndocumentableError, obj.source
        end
      end

      def append_name(sexp, name)
        prefix = sexp.jump(:ident, :string_content)
        if prefix == sexp
          raise YARD::Parser::UndocumentableError, sexp.source
        end

        "#{prefix[0]}.#{name}"
      end

      def synthetic_setting(name, value=nil)
        args = s( s(:string_literal, s(:string_content, s(:tstring_content, name))))
        args << value unless value.nil?
        args << false
        new_call = s(:fcall, s(:ident, "setting"), s(:arg_paren, args))
        new_call.line_range = (1..1)
        new_call.traverse do |node|
          node.full_source ||= ""
        end
        new_call.full_source = "setting('#{name}'#{value.nil? ? "" : ", #{value.source}"})"
        new_call

      end

      def process
        #filter further based on NS === Configurable...
        name = extract_name(statement.parameters.first)

        value = statement.parameters(false)[1]
        if !value.nil? and value.type == :fcall and value.jump(:ident)[0] == "nested"
          remapped = value.parameters(false).first.map do |assoc|
            new_name =
                append_name(statement.parameters[0], extract_name(assoc[0]))
            synthetic_setting(new_name, assoc[1])
          end
          parser.process(remapped)
          return
        end

        setting = YARD::CodeObjects::MethodObject.new(namespace, name) do |set|
          unless value.nil?
            set['default_value'] = statement.parameters(false)[1].source
          end
          set.signature = "def #{name}"
          if statement.comments.to_s.empty?
            set.docstring = "The value of setting #{name}"
          else
            set.docstring = statement.comments
          end

          set.dynamic = true
        end

        register setting
        (namespace[:settings] ||= []) << setting
      end
    end

    class SettingsHandler < SettingHandler
      handles method_call(:settings)
      namespace_only

      def process
        remapped = statement.parameters(false).first.map do |assoc|
          new_name =
            append_name(statement.parameters[0], extract_name(assoc[0]))
          synthetic_setting(new_name, assoc[1])
        end
        parser.process(remapped)
      end
    end

    class NilFieldsHandler < SettingHandler
      handles method_call(:nil_field)
      handles method_call(:nil_fields)
      namespace_only

      def a_nil
        v = s(:kw, nil)
        v.full_source = "nil"
        v
      end

      def process
        remapped = statement.parameters(false).map do |name|
          synthetic_setting(extract_name(name), a_nil)
        end
        parser.process(remapped)
      end
    end

    class RequiredFieldsHandler < SettingHandler
      handles method_call(:required_field)
      handles method_call(:required_fields)
      namespace_only

      def process
        remapped = statement.parameters(false).map do |name|
          synthetic_setting(extract_name(name))
        end
        parser.process(remapped)
      end
    end
  end
end
