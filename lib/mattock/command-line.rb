module Mattock
  class CommandRunResult
    def initialize(status, streams)
      @process_status = status
      @streams = streams
    end
    attr_reader :process_status, :streams

    def stdout
      @streams[1]
    end

    def stderr
      @streams[2]
    end

    def exit_code
      @process_status.exitstatus
    end
    alias exit_status exit_code

    def succeeded?
      must_succeed!
      return true
    rescue
      return false
    end

    def must_succeed!
      case exit_code
      when 0
        return exit_code
      else
        fail "Command '#{name}' failed with exit status #{$?.exitstatus}: \n"
      end
    end
  end

  class CommandLine
    def initialize(executable, *options)
      @executable = executable
      @options = options
      @redirections = []
      yield self if block_given?
    end

    attr_accessor :name, :executable, :options

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

    def self.execute(command)
      pipe = IO.popen(command)
      pid = pipe.pid
      pid, status = Process.wait2(pid)
      result = CommandRunResult.new(status, {1 => pipe.read})
      pipe.close
      return result
    end

    def run
      print command + " " if $verbose
      result = self.class.execute(command)
      print "=> #{result.exit_code}" if $verbose
      return result
    ensure
      puts if $verbose
    end

    def succeeds?
      run.succeeded?
    end

    def must_succeed!
      run.must_succeed!
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
