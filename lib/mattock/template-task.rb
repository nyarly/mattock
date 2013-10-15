require 'mattock/task'
module Mattock
  class TemplateTask < Mattock::Rake::FileTask
    setting :templates
    setting :source_path
    setting :local_variables, {}
    setting :context

    path :target

    setting :search_dirs, []

    def default_configuration(context)
      super

      self.context = context

      if field_unset?(:task_name)
        unless field_unset?(:source_path)
          target.relative_path = source_path
        end
      end
    end

    def resolve_configuration
      if field_unset?(:source_path)
        self.source_path = File::basename(task_name)
      end

      if target.field_unset?(:relative_path)
        target.absolute_path = task_name
      end

      self.templates ||=
        begin
          require 'valise'
          Valise::read_only(*search_dirs).templates
        end

      resolve_paths

      super
    end

    def action(args)
      File::open(target.absolute_path, "w") do |target|
        target.write(templates.find(source_path).contents.render(context, local_variables))
      end
    end
  end
end
