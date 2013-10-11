module Mattock
  class CommandLine
    class CommandRunResult
      def initialize(pid, command)
        @command = command
        @pid = pid

        #####
        @process_status = nil
        @streams = {}
        @consume_timeout = nil
      end
      attr_reader :process_status, :pid
      attr_accessor :consume_timeout, :streams

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

      def wait
        @accumulators = {}
        waits = {}
        @buffered_echo = []

        ioes = streams.values
        ioes.each do |io|
          @accumulators[io] = []
          waits[io] = 3
        end
        begin_echoing = Time.now + (@consume_timeout || 3)

        @live_ioes = ioes.dup

        until @live_ioes.empty? do
          newpid, @process_status = Process.waitpid2(pid, Process::WNOHANG)

          unless @process_status.nil?
            consume_buffers(@live_ioes)
            break
          end

          timeout = 0

          if !@buffered_echo.nil?
            timeout = begin_echoing - Time.now
            if timeout < 0
              puts
              puts "Long running command output:"
              puts @buffered_echo.join
              @buffered_echo = nil
            end
          end

          if timeout > 0
            result = IO::select(@live_ioes, [], @live_ioes, timeout)
          else
            result = IO::select(@live_ioes, [], @live_ioes, 1)
          end

          unless result.nil? #timeout
            readable, _writeable, errored = *result
            unless errored.empty?
              raise "Error on IO: #{errored.inspect}"
            end

            consume_buffers(readable)
          end
        end

        if @process_status.nil?
          newpid, @process_status = Process.waitpid2(pid)
        end

        ioes.each do |io|
          io.close
        end
        @streams = Hash[ioes.each_with_index.map{|io, index| [index + 1, @accumulators[io].join]}]
      end

      def consume_buffers(readable)
        if not(readable.nil? or readable.empty?)
          readable.each do |io|
            begin
              while chunk = io.read_nonblock(4096)
                if @buffered_echo.nil?
                  print chunk
                else
                  @buffered_echo << chunk
                end
                @accumulators[io] <<  chunk
              end
            rescue IO::WaitReadable => ex
            rescue EOFError => ex
              @live_ioes.delete(io)
            end
          end
        end
      end
    end
  end
end
