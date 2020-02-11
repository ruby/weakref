# Weakref

Weak Reference class that allows a referenced object to be
garbage-collected.

A WeakRef may be used exactly like the object it references.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'weakref'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install weakref

## Usage

```ruby
foo = Object.new            # create a new object instance
p foo.to_s                  # original's class
foo = WeakRef.new(foo)      # reassign foo with WeakRef instance
p foo.to_s                  # should be same class
GC.start                    # start the garbage collector
p foo.to_s                  # should raise exception (recycled)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby/weakref.
