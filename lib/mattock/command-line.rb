require 'mattock/command-line/command-run-result'

module Mattock
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
    attr_reader :redirections

    alias_method :command_environment, :env

    def set_env(name, value)
      command_environment[name] = value
      return self
    end

    def verbose
      ::Rake.verbose && ::Rake.verbose != ::Rake::FileUtilsExt::DEFAULT
    end

    def name
      @name || executable
    end

    def command
      ([executable] + options_composition + @redirections).join(" ")
    end

    def string_format
      (command_environment.map do |key, value|
        [key, value].join("=")
      end + [command]).join(" ")
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

    def replace_us
      puts "Ceding execution to: "
      puts string_format
      Process.exec(command_environment, command)
    end

    def spawn_process
      host_stdout, cmd_stdout = IO.pipe
      host_stderr, cmd_stderr = IO.pipe

      pid = Process.spawn(command_environment, command, :out => cmd_stdout, :err => cmd_stderr)
      cmd_stdout.close
      cmd_stderr.close

      return pid, host_stdout, host_stderr
    end

    def collect_result(pid, host_stdout, host_stderr)
      result = CommandRunResult.new(pid, self)
      result.streams = {1 => host_stdout, 2 => host_stderr}
      result.wait
      return result
    end

    #If I wasn't worried about writing my own limited shell, I'd say e.g.
    #Pipeline would be an explicit chain of pipes... which is probably as
    #originally intended :/
    def execute
      collect_result(*spawn_process)
    end

    #Run a command in the background.  The command can survive the caller
    def spin_off
      pid, out, err = spawn_process
      Process.detach(pid)
      return pid, out, err
    end

    #Run a command in parallel with the parent process - will kill it if it
    #outlasts us
    def background
      pid, out, err = spawn_process
      Process.detach(pid)
      at_exit do
        kill_process(pid)
      end
      return pid, out, err
    end

    def kill_process(pid)
      Process.kill("INT", pid)
    end

    def complete(pid, out, err)
      kill_process(pid)
      collect_result(pid, out, err)
    end

    def run
      print string_format + " "
      result = execute
      puts "=> #{result.exit_code}"
      puts result.format_streams if verbose
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

    def escaped_command(*args, &block)
      ShellEscaped.new(CommandLine.new(*args, &block))
    end
  end

  class ShellEscaped < CommandLine
    def initialize(cmd)
      @escaped = cmd
    end

    def command
      "'" + @escaped.string_format.gsub(/'/,"\'") + "'"
    end

    def command_environment
      {}
    end

    def name
      @name || @escaped.name
    end

    def to_s
      command
    end
  end

  class CommandChain < CommandLine
    def initialize
      @commands = []
      @command_environment = {}
      super(nil)
    end

    attr_reader :commands

    def add(cmd)
      yield cmd if block_given?
      @commands << cmd
      self
    end

    #Honestly this is sub-optimal - biggest driver for considering the
    #mini-shell approach here.
    def command_environment
      @command_environment = @commands.reverse.inject(@command_environment) do |env, command|
        env.merge(command.command_environment)
      end
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
