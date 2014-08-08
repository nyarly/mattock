## Mattock

A framework for defining complex Rake task libraries. Mattock complements Rake
by adding composible tasklibs, as well as hooks for command line composition
and templating.

### Configurable Tasklibs

Rake suggests an idiom for Tasklibs that works very well:

    Tasklib.new do |t|
      t.config = :x
    end

And that defines some tasks.  Rake's default Tasklib class doesn't do much to
support that idiom though, so Mattock's first purpose is to add support for
default settings, a yield into a configuration block, and the a setting
resolution step. To get started, check out {Mattock::TaskLib}

### Easy templating

One thing that Thor has on Rake is the ease with which templates can be
rendered to files.  Mattock::TemplateHost makes it easy to render overridable
templates based on the object it's included into.

For more information, check out http://nyarly.github.com/mattock/
