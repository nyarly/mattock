require 'mattock/configurable'

module Mattock
  #Collects shared configuration management behavior for TaskLibs and Tasks
  #
  #The chain of events in initialize looks like:
  #
  #    setup_defaults
  #    default_configuration(*tasklibs)
  #
  #    yield self if block_given?
  #
  #    resolve_configuration
  #    confirm_configuration
  #
  #    define
  #
  #(see #setup_cascade)
  #
  #Override those methods to adjust how a TaskLib processes its options
  #
  #The only method not defined here is {Configurable#setup_defaults}
  #
  #For an overview see {TaskLib}
  module CascadingDefinition
    include Configurable

    def setup_cascade(*other_definitions)
      @runtime = false
      setup_defaults

      confirm_steps(:default_configuration, :resolve_configuration, :confirm_configuration) do
        default_configuration(*other_definitions)

        yield self if block_given?

        resolve_configuration
        confirm_configuration
      end

      define
    end

    def confirm_steps(*steps)
      @steps = steps
      yield
      unless @steps.empty?
        #Otherwise, it's very easy to forget the 'super' statement and leave
        #essential configuration out.  The result is really confusing
        raise "#{self.class.name} didn't run superclass step#{@steps.length == 1 ? "" : "s"}: #{@steps.inspect} (put a 'super' in appropriate methods)"
      end
    end

    def confirm_step(step)
      @steps.delete(step)
    end

    #@param [TaskLib] tasklibs Other libs upon which this one depends to set
    #  its defaults
    #Sets default values for library settings
    def default_configuration(*tasklibs)
      confirm_step(:default_configuration)
    end

    #Called after the configuration block has been called, so secondary
    #configurations can be set up.  For instance, consider:
    #
    #    self.command = bin_dir + command_name if is_unset?(:command)
    #
    #The full path to the command could be set in the configuration block in
    #the Rakefile, or if bin_dir and command_name are set, we can put those
    #together.
    def resolve_configuration
      confirm_step(:resolve_configuration)
    end

    #Last step before definition: confirm that all the configuration settings
    #have good values.  The default ensures that required settings have been
    #given values.  Very much shortens the debugging cycle when using TaskLibs
    #if this is well written.
    def confirm_configuration
      confirm_step(:confirm_configuration)
      check_required
    end


    #Any useful TaskLib will override this to define tasks, essentially like a
    #templated Rakefile snippet.
    def define
    end
  end

  module DeferredDefinition
    def self.add_settings(mod)
      mod.setting(:configuration_block, proc{})
    end

    def setup_deferred
      @runtime = false
      @finalized = false
    end

    def runtime_definition(&block)
      self.configuration_block = block
    end

    def runtime?
      !!@runtime
    end

    def finalize_configuration
      return if @finalized
      @runtime = true
      configuration_block[self]
      confirm_steps(:resolve_runtime_configuration, :confirm_configuration) do
        resolve_runtime_configuration
        confirm_configuration
      end
      @finalized = true
    end

    def resolve_runtime_configuration
      confirm_step(:resolve_runtime_configuration)
    end
  end
end
