require 'mattock'

module Mattock
  class TarballTask < Rake::FileCommandTask
    setting :compression, :auto
    setting :compression_flag, nil
    setting :exclude_vcs, true

    dir(:unpacked_parent, dir(:unpacked_dir))
    dir(:archive_parent, path(:archive))

    setting :basename, nil
    setting :extension, "tbz"

    def default_configuration
      super
      self.compression_flag ||=
        case compression
        when :auto
          "--auto-compress"
        when :gzip
          "--gzip"
        when :bzip, :bzip2
          "--bzip2"
        when :xz
          "--xz"
        when :lzip
          "--lzip"
        when :lzma
          "--lzma"
        when :lzop
          "--lzop"
        when :compress
          "--compress"
        else
          ""
        end

      self.basename = name
    end

    def resolve_configuration
      extension.sub(/[.]$/,'')

      unpacked_parent.absolute_path ||= absolute_path
      archive_parent.absolute_path ||= absolute_path

      unless basename.nil?
        unpacked_dir.relative_path ||= basename
        archive.relative_path ||= [basename, extension].join(".")
      end

      resolve_paths
      super
    end

    def action_flag(string)
      case string
      when "c", /create/
        "--create"
      when "x", /extract/
        "--extract"
      when "d", /compare/
        "--compare"
      else
        string
      end
    end

    def add_options(tar)
      tar.options << "--files-from=" + listfile
    end

    def tar_command(action, verbose = true, &block)
      tar_command_without_directory(action, verbose) do |tar|
        tar.options << "--directory="+unpacked_dir.absolute_path
        yield tar if block_given?
      end
    end

    def tar_command_without_directory(action, verbose = true)
      command = cmd("tar") do |tar|
        tar.options << action
        tar.options << "--verbose" if verbose
        tar.options << compression_flag
        tar.options << "--file="+archive.absolute_path
        tar.options << "--exclude-vcs" if exclude_vcs
        yield(tar) if block_given?
      end
      return command
    end
  end

  class PackTarballTask < TarballTask
    default_taskname :pack_tarball
    path :listfile

    def command
      tar_command("--create") do |tar|
        tar.options << "--files-from="+listfile.absolute_path
      end
    end

    def define
      super
      if prerequisite_tasks.empty?
        enhance(source_files)
      end
    end
  end

  class ArchiveListTask < Rake::FileTask
    dir(:unpacked_dir)
    setting(:source_files)

    def needed?
      return true if super
      #the existing state of the file maps to the contents of the file
      return (File::read(name) == file_list)
    end

    def file_list
      @file_list ||=
        begin
          source_files.map do |path|
            Pathname.new(path)
          end.find_all do |pathname|
            not (pathname.directory? and not pathname.children.empty?)
          end.map do |pathname|
            pathname.relative_path_from unpacked_dir.pathname
          end
        end
    end

    def action(args)
      File::open(name, "w") do |list|
        list.write(file_list.join("\n"))
      end
    end
  end

  class UnpackTarballTask < TarballTask
    default_taskname :unpack_tarball

    def command
      (cmd("mkdir", "-p", unpacked_dir.absolute_path) & tar_command("--extract")) #ok
    end

    def target_files
      FileList[tar_command_without_directory("--list", false).run.stdout.split.map do |path|
        unpacked_dir.pathname.join(path).to_s
      end]
    end

    def create_target_dependencies
      target_files.each do |path|
        ::Rake::FileTask.define_task(path => name)
      end
    end

    def needed?
      return true if super
      if File::exists?(archive_path.absolute_path)
        return !(tar_command("--compare")).succeeds?
      end
      return true
    end
  end

  class PackTarball < Tasklib
    default_namespace :pack

    dir(:unpacked_dir)

    dir(:marshalling,
       path(:listfile),
       path(:archive))

    setting :basename, nil
    setting :extension, "tbz"
    setting :source_files
    setting :source_pattern, "**/*"
    setting :exclude_patterns, ['**/*.sw[^f]'] #ok

    def resolve_configuration
      listfile.relative_path ||= "#{basename}.list"
      unless basename.nil?
        self.unpacked_dir.relative_path ||= basename
        self.archive.relative_path ||= [basename, extension].join(".")
      end

      resolve_paths

      self.source_files ||=
        begin
          pattern = File::join(unpacked_dir.absolute_path, source_pattern)
          list = FileList[pattern]
          exclude_patterns.each do |pattern|
            list.exclude(pattern)
          end
          list
        end

      super
    end

    def define
      super
      in_namespace do
        ArchiveListTask.define_task(listfile.absolute_path => [::Rake.application.rakefile, marshalling.absolute_path] + source_files) do |task|
          copy_settings_to(task)
        end

        PackTarballTask.define_task(archive.absolute_path => listfile.absolute_path) do |task|
          copy_settings_to(task)
        end
        task archive.absolute_path => ::Rake.application.rakefile unless ::Rake.application.rakefile.nil?
      end
    end
  end

  class UnpackTarballs < Tasklib
    class RemoveFilesNotInArchives < TarballTask
      dir :unpacked_dir

      setting :archive_paths
      setting :file_list

      attr_accessor :stray_files

      def resolve_configuration
        resolve_paths

        super
      end

      def stray_files
        @stray_files ||=
          begin
            archive_paths.each do |archive_path|
              list_process = tar_command("--list")
              if list_process.succeeds?
                self.archive_files += list_process.stdout.lines.to_a.map{|line| line.chomp}
              end
            end
            archive_files.map!{|path| File::expand_path(path, target_dir)}

            self.stray_files = file_list - archive_files
            stray_files.delete_if{|path| File::directory?(path)}
            unsafe_cleanup = stray_files.find_all do |path|
              %r{\A/} =~ path and not %r{\A#{File::expand_path(target_dir)}} =~ path
            end
            raise "Unsafe stray cleanup: #{unsafe_cleanup.inspect}" unless unsafe_cleanup.empty?
            stray_files
          end
      end

      def needed?
        stray_files.any? do |path|
          File.exists?(path)
        end
      end

      def command
        cmd("rm", "-f", *stray_files)
      end
    end

    default_namespace :unpack

    setting :archive_paths, []
    setting :archive_path, nil

    dir :unpacked_dir
    setting :target_pattern, "**/*"
    setting :file_list

    def resolve_configuration
      unless archive_path.nil?
        archive_paths << archive_path
      end

      resolve_paths

      self.file_list ||= FileList[File::join(File::expand_path(target_dir),target_pattern)]

      super
    end

    def define
      in_namespace do
        archive_paths.each do |archive|
          UnpackTarballTask.define_task(archive) do |unpack|
            copy_settings_to(unpack)
            unpack.archive_path.absolute_path = archive
          end
        end

        if file_list.empty?
          task :unpack => archive_paths
        else
          RemoveFilesNotInArchives.define_task(:remove_strays => archive_paths) do |remove_strays|
            copy_settings_to(remove_strays)
          end

          task :unpack => file_list
          file_list.each do |path|
            file path => :remove_strays
          end
        end
      end

      task namespace_name => self[:unpack]
    end
  end

  UnpackTarball = UnpackTarballs
end
