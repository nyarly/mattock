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

  module CommandLineExampleGroup
    def self.included(group)
      group.class_eval do
        let :pairs do
          []
        end

        before :each do
          Mattock::CommandLine.should_receive(:execute) do |cmd|
            pattern, res = pairs.shift
            pattern.should =~ cmd
            Mattock::MockCommandResult.create(*res)
          end.any_number_of_times
        end

        after :each do
          pairs.should have_all_been_called
        end
      end
    end

    #XXX This could probably just be a direct wrapper on #should_receive...
    def expect_command(cmd, *result)
      raise ArgumentError, "Regexp expected: not #{cmd.inspect}" unless Regexp === cmd
      pairs << [cmd, result]
    end

    module Matchers
      extend RSpec::Matchers::DSL

      define :have_all_been_called do
        match do |list|
          list.empty?
        end

        failure_message_for_should do |list|
          "Expected all commands to be run, but: #{list.map{|item| item[0].source.inspect}.join(", ")} #{list.length > 1 ? "were" : "was"} not."
        end
      end
    end
    include Matchers
  end
end
