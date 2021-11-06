# Waypoint -- track (and presumably log) progress in batch jobs

Never again write code of the form `log.info "Finished 1_000 in # {secs} 
seconds at a rate of #{total / secs}"`. 

## Usage

```ruby

require 'waypoint'
require 'logger'
input_file = "records.ndj"

# Create a new waypoint. Default batch_size is 1_000
wp = Waypoint.new(name: "Load #{input_file}", batch_size: 1_000_000)
logger = Logger.new(STDERR)

File.open(input_file).each do |line|
  do_whatever_needs_doing(line)
  wp.incr
  # spit out a log line every batch_size records
  wp.on_batch { logger.info wp.batch_line} 
end

logger.info wp.final_line

# Sample output
# ...
# I, [2021-11-02T01:51:06.959137 #11710]  INFO -- : load records.ndj   8_000_000. This batch 2_000_000 in 26.2s (76_469 r/s). Overall 72_705 r/s.
# I, [2021-11-02T01:51:36.992831 #11710]  INFO -- : load records.ndj  10_000_000. This batch 2_000_000 in 30.0s (66_591 r/s). Overall 71_394 r/s.
# ...
# I, [2021-11-02T02:01:56.702196 #11710]  INFO -- : load records.ndj FINISHED. 27_138_118 total records in 00h 12m 39s. Overall 35_718 r/s.

```

### Incorporating a logger into waypoint

For standard logging cases, you can also pass in a logger, or let waypoint 
create one for its own use based on an IO-like object you provide

```ruby
logger = Logger.new(STDERR)
wp = Waypoint.new(name: 'my_process', batch_size: 10_000, logger: logger)

# same thing
wp = Waypoint.new(name: 'my_process', batch_size: 10_000)
wp.logger = logger

# same thing
wp = Waypoint.new(name: 'my_process', batch_size: 10_000)
wp.create_logger!(STDERR)

File.open(input_file).each do |line|
  do_whatever_needs_doing(line)
  wp.increment_and_log # same as wp.on_batch { logger.info wp.batch_line}
end

```

### Structured logging

`Waypoint::Structured` will return hashes for `#batch_line` and `#final_line`
(aliased to `#batch_data` and `#final_data`, respectively) and pass those
hashes along to whatever logger you provide. `#create_logger!` will create
a logger that provides json lines instead of text, too.

Presumably, if you pass in a logger you'll use something like
[semantic_logger](https://github.com/reidmorrison/semantic_logger) 
or [ougai](https://github.com/tilfin/ougai).

```ruby
wp = Waypoint::Structured.new(name: 'my_process', batch_size: 10_000)
wp.create_logger!(STDERR)

File.open(input_file).each do |line|
  do_whatever_needs_doing(line)
  wp.increment_and_log
end

# Usually one line; broken up for readability
# {"name":"my_process","batch_count":10_000,"batch_seconds":97.502088,
# "batch_rate":1.035875252230496,"total_count":100,"total_seconds":97.502094,
# "total_rate":1.0358751884856956,"level":"INFO","time":"2021-11-06 17:32:21 -0400"}

```

## Non-logging uses

Note that since `wp.on_batch { block }` simply fires whenever `batch_size`
calls to `#incr` have been recorded,  There's no reason one can't use this
to, say, send a collected batch of data to a database.

```ruby
accum = []
File.open(input_file).each do |line|
  accum << transform_line(line)
  wp.incr
  wp.on_batch do
    send_to_database(accum)
    accum = []
  end
end

```

## Accuracy

Note that `Waypoint` isn't designed for real benchmarking. 
The assumption is that whatever work your code is actually
doing will drown out any inefficiencies in the `Waypoint` code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'waypoint'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install waypoint


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/billdueber/waypoint.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
