# frozen_string_literal: true

require_relative  "../lib/milemarker"
require_relative '../lib/ppnum'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# @param [Integer] batch_size
# @param [Integer] count
# @return [Milemarker]
def basic_mm(batch_size, count, &blk)
  mm = Milemarker.new(batch_size: batch_size)
  (1..count).each do |i|
    mm.increment_and_on_batch { blk.call(i, mm) }
  end
  mm
end

# Use the form
# expect { print('foo') }.to output(/foo/).to_stdout