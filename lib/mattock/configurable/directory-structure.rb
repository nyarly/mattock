require 'rake'

module Mattock
  module Configurable
    class MissingRelativePaths < Exception; end

    #XXX Consider making the actual dir/path settings r/o
    #Very easy to say
    #  filename = "string"
    #rather than
    #  filename.relative_path = "string"
    #and it isn't clear which (abs/rel) you mean
    #
    module DirectoryStructure
      class StructurePath
        include Configurable

        setting :absolute_path
        setting :relative_path

        alias abspath absolute_path
        alias relpath relative_path

        #No #path - ambiguous whether that would be abspath or pathname

        def initialize(rel_path)
          self.relative_path = rel_path unless rel_path == Configurable::RequiredField
        end

        def pathname
          @pathname ||=
            begin
              fail_unless_set(:absolute_path)
              require 'pathname'
              Pathname.new(absolute_path)
            end
        end
        alias path_name pathname

        if (false)
        def inspect
          "<path: #{
            if field_unset?(:absolute_path)
              if field_unset?(:relative_path)
                "<<?>>"
              else
                "?/#{relative_path}"
              end
            else
              absolute_path.inspect
            end
          }>"
        end
        end
      end

      module ClassMethods
        RequiredField = Configurable::RequiredField

        def root_paths
          @root_paths ||= []
        end

        def path_heirarchy
          @path_heirarchy ||= []
        end
        attr_writer :path_heirarchy

        def path_fields
          @path_fields ||= []
        end

        def dir(field_name, *args)
          rel_path = RequiredField
          if String === args.first
            rel_path = args.shift
          end
          parent_field = path(field_name, rel_path)

          root_paths << parent_field
          self.path_heirarchy += args.map do |child_field|
            [parent_field, child_field]
          end
          return parent_field
        end

        def path(field_name, rel_path=RequiredField)
          field = setting(field_name, StructurePath.new(rel_path))
          root_paths << field
          path_fields << field
          return field
        end

        def resolve_path_on(instance, parent, child_field, missing_relatives)
          child = child_field.value_on(instance)
          return unless child.field_unset?(:absolute_path)
          if child.field_unset?(:relative_path)
            missing_relatives << child_field
            return
          end
          child.absolute_path = File::join(parent.absolute_path, child.relative_path)
        end

        def resolve_paths_on(instance)
          superclass_exception = nil
          if superclass < DirectoryStructure
            begin
            superclass.resolve_paths_on(instance)
            rescue MissingRelativePaths => mrp
              superclass_exception = mrp
            end
          end
          missing_relatives = []

          (root_paths - path_heirarchy.map{|_, child| child }).each do |field|
            resolve_path_on(instance, instance, field, missing_relatives)
          end

          path_heirarchy.reverse.each do |parent_field, child_field|
            parent = parent_field.value_on(instance)
            resolve_path_on(instance, parent, child_field, missing_relatives)
          end

          case [missing_relatives.empty?, superclass_exception.nil?]
          when [true, false]
            raise superclass_exception
          when [false, true]
            raise MissingRelativePaths, "Required field#{missing_relatives.length == 1 ? "" : "s"} #{missing_relatives.map{|field| "#{field.name}.relative_path".inspect}.join(", ")} unset on #{self.inspect}"
          when [false, false]
            raise MissingRelativePaths, "Required field#{missing_relatives.length == 1 ? "" : "s"} #{missing_relatives.map{|field| "#{field.name}.relative_path".inspect}.join(", ")} unset on #{self.inspect}" + "\n" + superclass_exception.message
          end

          path_fields.each do |field|
            value = field.value_on(instance)
            next unless value.field_unset?(:relative_path)
            value.relative_path = value.absolute_path
          end
        end
      end

      def self.included(sub)
        sub.extend ClassMethods
        dir_path =
          if not (file_path = ::Rake.application.rakefile).nil?
            File::dirname(File::expand_path(file_path))
          elsif not (dir_path = ::Rake.application.original_dir).nil?
            dir_path
          else
            file_path = caller[0].split(':')[0]
            File::dirname(File::expand_path(file_path))
          end
        sub.setting :absolute_path, dir_path
      end

      def resolve_paths
        self.class.resolve_paths_on(self)
      end
    end
  end
end
