module Mattock
  class CommandRunResult
    def initialize(command, status, streams)
      @command = command
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
        fail "Command #{@command.inspect} failed with exit status #{exit_code}: \n#{streams.inspect}"
      end
    end
  end

  class CommandLine
    def self.define_chain_op(opname, klass)
      define_method(opname) do |other|
        unless CommandLine === other
          other = CommandLine.new(*[*other])
        end
        chain = nil
        if klass === self
          chain = self
        else
          chain = klass.new
          chain.add(self)
        end
        chain.add(other)
      end
    end

    def self.define_op(opname)
      CommandLine.define_chain_op(opname, self)
    end

    def initialize(executable, *options)
      @executable = executable
      @options = options
      @redirections = []
      @env = {}
      yield self if block_given?
    end

    attr_accessor :name, :executable, :options, :env

    def verbose
      Rake.verbose && Rake.verbose != Rake::FileUtilsExt::DEFAULT
    end

    def name
      @name || executable
    end

    def command
      (set_env + [executable] + options_composition + @redirections).join(" ")
    end

    def set_env
      @env.map do |key, value|
        [key, value].join("=")
      end
    end

    def options_composition
      options
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
      result = CommandRunResult.new(command, status, {1 => pipe.read})
      pipe.close
      return result
    end

    def run
      print command + " " if verbose
      result = self.class.execute(command)
      print "=> #{result.exit_code}" if verbose
      return result
    ensure
      puts if verbose
    end

    def succeeds?
      run.succeeded?
    end

    def must_succeed!
      run.must_succeed!
    end
  end

  module CommandLineDSL
    def cmd(*args, &block)
      CommandLine.new(*args, &block)
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
      self
    end

    def name
      @name || @commands.last.name
    end
  end

  class WrappingChain < CommandChain
    define_op('-')

    def command
      @commands.map{|cmd| cmd.command}.join(" -- ")
    end
  end

  class PrereqChain < CommandChain
    define_op('&')

    def command
      @commands.map{|cmd| cmd.command}.join(" && ")
    end
  end

  class PipelineChain < CommandChain
    define_op('|')

    def command
      @commands.map{|cmd| cmd.command}.join(" | ")
    end
  end
end
