require 'mattock/tasklib'

module Mattock
  class CommandTaskLib < TaskLib
    include Caliph::CommandLineDSL
  end
end
