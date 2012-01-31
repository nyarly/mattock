## Mattock

Another tool to use with Rake.  Mattock is a collection of handy Rake
extensions I've been using elsewhere and generalized.

### Configurable Tasklibs

Rake suggests an idiom for Tasklibs that works very well:

    Tasklib.new do |t|
      t.config = :x
    end

And that defines some tasks.  Rake's default Tasklib class doesn't do much to
support that idiom though, so Mattock's first purpose is to add support for
default settings, a yield into a configuration block, and the a setting
resolution step.

### A Command line scripting API

There's two reasons to do something more complicate that good old

     sh 'rm -rf *'

First is composibility.  With a Mattock::CommandLine, you can pass the
resulting command around and modify it's arguments or encorporate it into a
larger pipeline easily.

Second is testability.  You can mock out all command line execution and provide
fake responses.  Additionally, command results can be recorded to make that
process easier.

### Easy templating

One thing that Thor has on Rake is the ease with which templates can be
rendered to files.  Mattock::TemplateHost makes it easy to render overridable
templates based on the object it's included into.
