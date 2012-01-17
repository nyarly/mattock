module Mattock
  class CommandLine
    def initialize(executable, *options)
      @executable = executable
      @options = options
      @redirections = []
      @exit_status = nil
      @stdout = nil
      yield self if block_given?
    end

    attr_accessor :name, :executable, :options
    attr_reader :exit_status, :stdout

    def name
      @name || executable
    end

    def command
      ([executable] + options + @redirections).join(" ")
    end

    def redirect_to(stream, path)
      @redirections << "#{stream}>#{path}"
    end

    def redirect_from(path, stream)
      @redirections << "#{stream}<#{path}"
    end

    def copy_stream_to(from, to)
      @redirections << "#{from}>&#{to}"
    end

    def redirect_stdout(path)
      redirect_to(1, path)
    end

    def redirect_stderr(path)
      redirect_to(2, path)
    end

    def redirect_stdin(path)
      redirect_from(path, 0)
    end

    def run
      print command + " " if Rake::verbose
      pipe = IO.popen(command)
      pid = pipe.pid
      Process.wait(pid)
      @stdout = pipe.read
      pipe.close
      @exit_status = $?.exitstatus
      print "=> #@exit_status" if Rake::verbose
      return @stdout
    ensure
      puts if Rake::verbose
    end

    def succeeds?
      run if @exit_status.nil?
      succeeded?
    end

    def succeeded?
      must_succeed!
      return true
    rescue
      return false
    end

    def must_succeed!
      case @exit_status
      when nil
        fail "Command '#{name}' hasn't completed yet."
      when 0
        return @exit_status
      else
        fail "Command '#{name}' failed with exit status #{$?.exitstatus}: \n"
      end
    end
  end

  class ShellEscaped < CommandLine
    def initialize(cmd)
      @escaped = cmd
    end

    def command
      "'" + @escaped.command.gsub(/'/,"\'") + "'"
    end

    def name
      @name || @escaped.name
    end
  end

  class CommandChain < CommandLine
    def initialize
      @commands = []
      yield self if block_given?
    end

    attr_reader :commands

    def add(cmd)
      yield cmd if block_given?
      @commands << cmd
    end

    def name
      @name || @commands.last.name
    end
  end

  class WrappingChain < CommandChain
    def command
      @commands.map{|cmd| cmd.command}.join(" -- ")
    end
  end

  class PrereqChain < CommandChain
    def command
      @commands.map{|cmd| cmd.command}.join(" && ")
    end
  end

  class PipelineChain < CommandChain
    def command
      @commands.map{|cmd| cmd.command}.join(" | ")
    end
  end
end
