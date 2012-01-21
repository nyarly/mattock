require 'mattock/command-line'

module Mattock
  class MockCommandResult < CommandRunResult
    def self.create(*args)
      if args.length == 1
        args = [args[0], {1 => ""}]
      end

      if String == args[1]
        args[1] = {1 => args[1]}
      end

      return self.new(*args)
    end

    def initialize(code, streams)
      @streams = streams
      @exit_code = code
    end

    attr_reader :exit_code, :streams

    alias exit_status exit_code
  end
end
