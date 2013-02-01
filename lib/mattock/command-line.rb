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

    def format_streams
      "stdout:#{stdout.nil? || stdout.empty? ? "[empty]\n" : "\n#{stdout}"}" +
      "stderr:#{stderr.nil? || stderr.empty? ? "[empty]\n" : "\n#{stderr}"}---"
    end

    def must_succeed!
      case exit_code
      when 0
        return exit_code
      else
        fail "Command #{@command.inspect} failed with exit status #{exit_code}: \n#{format_streams}"
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
    attr_reader :redirections

    alias_method :command_environment, :env

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

    def spawn_process
      host_stdout, cmd_stdout = IO.pipe
      host_stderr, cmd_stderr = IO.pipe

      pid = Process.spawn(command_environment, command, :out => cmd_stdout, :err => cmd_stderr)
      cmd_stdout.close
      cmd_stderr.close

      return pid, host_stdout, host_stderr
    end

    def collect_result(pid, host_stdout, host_stderr)
      pid, status = Process.wait2(pid)

      stdout = consume_buffer(host_stdout)
      stderr = consume_buffer(host_stderr)
      result = CommandRunResult.new(command, status, {1 => stdout, 2 => stderr})
      host_stdout.close
      host_stderr.close

      return result
    end

    #Gets all the data out of buffer, even if somehow it doesn't have an EOF
    #Escpecially useful for programs (e.g. ssh) that sometime set their stderr
    #to O_NONBLOCK
    def consume_buffer(io)
      accumulate = []
      waits = 3
      begin
        while chunk = io.read_nonblock(4096)
          accumulate << chunk
        end
      rescue IO::WaitReadable => ex
        retry if (waits -= 1) > 0
      end
      return accumulate.join
    rescue EOFError
      return accumulate.join
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
