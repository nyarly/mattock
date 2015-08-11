# Mattock


A framework for defining complex, reusable, configurable Rake task libraries.

Mattock complements Rake by adding composable tasklibs, as well as hooks for
command line composition and templating.

## Configurable Tasklibs

Rake includes a class called `Tasklib` which serves only as a common superclass
for task libraries. Rake ships with two such libraries: `Rake::PackageTask` and
`Rake::TestTask.` Other ruby libraries and gems (e.g. RSpec) include similar
tasklibs.  Most folk use them without knowing exactly how they work, which is
the whole point of encapsulation.

As a for instance, here's Rake::TestTask in use:
```ruby
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end
```

And that defines some tasks.  Rake's default Tasklib class doesn't do much to
support that idiom though. Most Tasklibs have an initialize that looks like
this:

```ruby
def initialize(name=:test)
  @name = name
  @libs = ["lib"]
  @pattern = nil
  @options = nil
  @test_files = nil
  @verbose = false
  @warning = false
  @loader = :rake
  @ruby_opts = []
  @description = "Run tests" + (@name == :test ? "" : " for #{@name}")
  yield self if block_given?
  @pattern = 'test/test*.rb' if @pattern.nil? && @test_files.nil?
  define
end
```
(that's actually TestTask's constructor verbatim.)

What's going on there? Well, first TestTask sets all its instance variables to
reasonable defaults. Then it yields itself into a block to be configured. It
wraps up by making sure that all its configuration is sensible, and then it
runs a `define` method which actually does the Rake task definition operations.

Clear and sensible, but it suffers by not being terribly well documented, and
by not being very extensible - if you want test behavior beyond what can be
configured, you essentially need to re-write TestTask.

## Enter Mattock

Mattock is a framework for producing reusable, configurable Rake task
libraries. The intention is that the direct audience for this gem is fairly
small: just people who write enough Rake tasks that they start to say "gee, I
wish I could parameterize this and re-use it elsewhere." Most users of Mattock
will see the task configuration interface, and hopefully will be delighted by
how much build functionality they can get just for configuring a few variables.

### Using Mattock Tasklibs

If you've come across a tasklib written in Mattock, it should work roughly the
way `Rake::TestTask` does: instantiate the tasklib in your Rakefile, and set
configuration values in a block. Then try something like

    > rake -T

to see what tasks it added for you.

The actual configuration options will be specific to each project, and should
be documented there. Mattock includes a YARD plug-in to make this easier, but
it's ultimately up to the authors of each tasklib to document the settings
document the settings document the settings.

## Writing Tasklibs with Mattock

Mattock formalizes the tasklib setup process.

### Setup phases

Mattock task libs *only* need to have a `define` method. Specifically, the
tasklib process looks like this:

* set up default configuration
* yield to the user to configure
* calculate any complex configuration
* check that configuration is correct
* define tasks

A simple tasklib, or one that you're just starting, can usually just be:

```ruby
class MyTaskLib < Mattock::Tasklib
  def define
    task :my_task do
      #...
    end
  end
end
```

Notice that the contents of the `define` method are just what you'd put into a
Rakefile. It's highly recommended to start a tasklib as a simple set of tasks,
and then wrap them in a `Mattock::Tasklib` subclass to distribute them.

### Configuration

Mattock provides a general purposes `Configurable` module, which
`Mattock::Tasklib` and `Mattock::Task` both take advantage of. It works like
this:

```
class MyTasklib < Mattock::Tasklib
  setting :name, "my-task-lib"
  nil_setting :optional_thing
  required_fields :cant_compute_this
end
```

The most basic class method here is `setting` - it just creates a special
attribute on the `Tasklib` class with a default value.

There's a variant of setting `settings` which take a hash and creates several
settings and their defaults all at once.

`nil_setting` is essentially sugar for `setting :name => nil`

`required_fields` create attributes on the tasklib that must be set - before
definition, the tasklib will raise an error if they're missed. Since Rake tasks
tend to be both expensive and destructive operations, it's better to be able to
constrain configuration to require certain settings be set by the user than to
have e.g. nil values there.

### Overriding Setup

Setting up a `#define` method is the only requirement of a useful tasklib, but
in general you'll need to take control of the setup phases to make your tasklib
really useful. Here are the methods you'll need override to change the default
behavior:

```ruby

class AdvancedTasklib < Mattock::Tasklib
  settings :first_name => "Jane", :last_name => "Smith"
  required_field :full_name

  def default_configuration
    super
    # sets up the default configuration, before the user sets anything
  end

  def resolve_configuration
    # called after the user has done configuration, ensuring that calculated
    # fields are set correctly
    self.full_name = [first_name, last_name].join(" ")
    super
  end

  def confirm_configuration
    # if you need to do validation above and beyond that required fields have
    # values, this is where to do it
    super
  end
end
```

One thing to note is a Ruby gotcha: when you are _assigning_ a setting, you
have to use the `self.setting =` form; otherwise Ruby prefers the meaning "I
want to create and assign a local variable." _Using_ a setting doesn't have
this restriction, but you might prefer to say things like

```ruby
self.full_name = [self.first_name, self.last_name].join(" ")
```

rather than remember which case is which.

Last point here: `Mattock` goes through great lengths to actually make settings
more-powerful versions of Ruby's `attr_*` methods, so if you want, you can us
the underlying `@instance_variables`. All a matter of preference.

### Configuration Tools

`Mattock::Configurable` settings have a lot of extra power associated with
them.  First of all, the `resolve_configuration` from above would probably be
better like this:

```ruby
def resolve_configuration
  if field_unset?(:full_name)
    self.full_name = [first_name, last_name].join(" ")
  end
end
```

In this case, you could probably have said `self.full_name ||= join_names()`
but the nice thing about `field_unset?` is that I does exactly what it says: if
the user set full_name to `nil`, that's still a setting (but it's a "falsy"
value, which means ||= would clobber it.)

The other utility function here are `from_hash(source_hash)` and `to_hash` -
which do essentially what they sound like. Especially handy to do a YAML.load
(or see [`Valise`](https://github.com/nyarly/valise)) to pull in a hash
from a file and configure a task from that.

### Validation

One thing to note in the setup override example is that all the overridden
methods have a call to `super` - that's important because while the default
behavior is pretty simple, if you inherit Tasklibs, the superclass overrides
are usually important, and it's really easy to forget the super call.

`Mattock` will actually raise an error before defining tasks if any of the
steps fail to call their superclass implementation.

Rarely you may need to avoid your superclass's implementation of e.g.
required_configuration (although maybe it would be better not to subclass in
this case).  You can get around it by calling e.g.
`#confirm_step(:required_configuration)`. Mostly it's just better to toss the
`super` call in there.

### Path Names

Because the most common settings for a Rake task tend to be paths to files -
the source and target files for a compiler, for instance - `Mattock` has a
convenience functions for creating and managing those.

```ruby
class MyTasklib < Mattock::Tasklib
  dir(:project,
    dir(:source_dir, "src",
      path(:source_file, "file.txt")),
    dir(:destination_dir, "dest",
      path(:target_file, "file.txt")))

  def define
    file target_file.abs_path => source_file.abs_path do
      sh "compilerify #{source_file.abs_path} > #{target_file.abs_path}"
    end
  end
end
```

```ruby
MyTasklib.new(:buildit) do |build|
  build.project.rel_path = "proj_dir"
end
```

```
> rake buildit
   compilerify proj_dir/src/file.txt > proj_dir/dest/file.txt
```

This is one of the nicest things Mattock does. The management of paths is a big
hassle for writing build scripts, and handling that in a coherent, expressive
way is really helpful. Furthermore, Mattock treats all of those rel_paths as
required fields.  This helps mitigate errors related to empty paths, e.g.
deleting all the files in the whole project.

### Composition

Complex tasklibs can be broken up into smaller tasklibs, which helps make them
more reusable. For instance, only part of a tasklib might be really useful in a
particular project, and it's helpful to be able to only include that part.

Related tasklibs tend to share configuration, however, and it'd be a hassle for
users to have to duplicate configuration, especially when some of one tasklibs
configuration comes from another's computed values.

`Mattock::Tasklib`s accept other `Tasklib`s (actually: other `Configurable`s)
as arguments to their `::new` method. The configurables get passed into
`#default_configuration` so that they can be used to set up configuration.

The most common use case is something like "copy all the fields with the same
name from that Tasklib to this one." There's a method on `Configurable` (and
therefore `Tasklib`) to support that, like so:

```ruby
class ParentTasklib < Mattock::Tasklib
  settings :first_name => "Jane", :last_name => "Smith"
end

class ChildTasklib < Mattock::Tasklib
  required_field :parent_name, :last_name, :age

  def default_configuration(parent)
    parent.copy_settings_to(self) #here's the copy
    self.parent_name = parent.first_name
  end
end
```

Usually used like:
```ruby
parent = ParentTasklib.new do |mom|
  mom.last_name = "Jones"
end

ChildTasklib.new(parent) do |kid|
  #kid.last_name is already "Jones" here
  kid.age = 6
end
```


### Utility functions

There are a few functions defined in `Mattock::Tasklib` that serve to simplify
the task definition process.

#### Namespaces
Tasklibs get `default_namespace` and `in_namespace`, which make managing
Rake namespaces easier.

```ruby
class MyTasks < Mattock::Tasklib
  default_namespace :mine

  def define
    in_namespace do #creates the correct namespace
      #... your tasks here ...

      task :taskname do
        #... do stuff ...
      end
    end

    task :default => in_namespace(:taskname) #refers to namespace
  end
end
```

Note that `default_namespace` just sets up a `namespace` setting with a default
value; users can change it the same way they'd change any other setting.

#### Task Dependency Patterns

When assembling and maintaining large sets of tasks, arranging their
dependencies can be kind of a hassle. Two utilities to help with that:

```ruby
def define
  task_spine(:first, :second, :third)

  task_bracket(:first, :one_and_a_half, :second)
end
```

`task_spine` sets up definitions of the named tasks such that they'll run in
the order specified.  So, in the example above `:third` will depend on
`:second` will depend on `:first`, and running `rake third` will do the three
tasks in order.

`task_bracket` sticks a task in the middle of two other tasks.

Using the two helpers together, you can build a main-line of a complex process
(its "spine") and then attach specific jobs to spots on the spine.


### Advanced Topics

#### Live Configuration

You may find that you need to handle configuration that you only know after the
Rakefile has been loaded. For instance, task arguments, or values pulled from
the network, or as the result of running a tool. Mattock has support for this
kind of "runtime" configuration, in the form of proxied values and the
DeferredDefinition module. If you find yourself needing those tools, you'll be
best off reviewing the full API guide. While `Mattock` supports those use
cases, you'll find that you're really stretching what Rake comfortably does.

#### Setting Metadata

One of the features of `Configurable` settings are that they have some extra
metadata that helps control how they're used. In general you don't need to
fiddle with them, but more complicated sets of tasklibs can get some value from
this feature. One solid example is this:

```ruby
def self.default_namespace(name)
  setting(:namespace, name).isnt(:copiable)
end
```

That's the verbatim definition of default_namespace. The `isnt(:copiable)`
serves to prevent `parent.copy_settings_to(self)` overriding the namespace of
the current task with the namespace of the "parent" task.

The metadata you can set on a field are `:copiable`, `:proxiable`, `:required`,
`:defaulting` and `:runtime`. `:copiable`, `:proxiable` and `:defaulting`
default to true (i.e. `.is(:copiable)`), but most of those changes are handled
by how the fields were defined in the first place.


### Related Projects

Mattock's configuration interfaces (e.g. `setting`) are implemented in a
separate gem called [Calibrate](https://git.lrdesign.com/lrd/calibrate) which
is designed to be used as a support library in other gems.
