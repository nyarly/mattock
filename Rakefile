require 'corundum'
require 'corundum/tasklibs'

require 'mattock/yard_extensions'

module Corundum
  extend Rake::DSL

  tk = Toolkit.new do |tk|
  end

  tk.in_namespace do
    GemspecFiles.new(tk)
    debug_kruft = QuestionableContent.new(tk) do |dbg|
      dbg.words = %w{p pry binding.pry debugger}
    end
    rspec = RSpec.new(tk)
    cov = SimpleCov.new(tk, rspec) do |cov|
      cov.threshold = 76
    end
    gem = GemBuilding.new(tk)
    cutter = GemCutter.new(tk,gem)
   # email = Email.new(tk)
    vc = Git.new(tk) do |vc|
      vc.branch = "master"
    end
    task tk.finished_files.build => vc["is_checked_in"]
    #yd = YARDoc.new(tk)

    #docs = DocumentationAssembly.new(tk, yd, rspec, cov)

    #pages = GithubPages.new(docs)
  end
end

task :default => [:release, :publish_docs]
