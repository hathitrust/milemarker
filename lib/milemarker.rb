# frozen_string_literal: true

require_relative "ppnum"
require 'logger'
require 'socket'
require 'json'

# milemarker class, to keep track of progress over time for long-running
# iterating processes
# @author Bill Dueber <bill@dueber.com>
class Milemarker

  # @return [String] optional "name" of this milemarker, for logging purposes
  attr_accessor :name

  # @return [Integer] batch size for computing `on_batch` calls
  attr_accessor :batch_size

  # @return [Logger, #info] logging object for automatic logging methods
  attr_accessor :logger

  # @return [Integer] which batch number (total increment / batch_size)
  attr_reader :batch_number

  # @return [Integer] number of second to process the last batch
  attr_reader :last_batch_seconds

  # @return [Integer] number of records (really, number of increments) in the last batch
  attr_reader :last_batch_size

  # @return [Time] Time the full process started
  attr_reader :start_time

  # @return [Time] Time the last batch started processing
  attr_reader :batch_start_time

  # @return [Time] Time the last batch ended processing
  attr_reader :batch_end_time

  # @return [Integer] Total records (really, increments) for the full run
  attr_reader :count

  # @return [Integer] Total count at the time of the last on_batch call. Used to figure out
  #   how many records were in the final batch
  attr_reader :prev_count

  # Create a new milemarker tracker, with an optional name and logger
  def initialize(batch_size: 1000, name: nil, logger: nil)
    @batch_size = batch_size
    @name       = name
    @logger     = logger

    @batch_number = 0
    @last_batch_size    = 0
    @last_batch_seconds = 0

    @start_time       = Time.now
    @batch_start_time = @start_time
    @batch_end_time   = @start_time

    @count      = 0
    @prev_count = 0
  end

  # Turn `increment_and_batch` (and thus `increment_and_log_batch_line`) into
  # a threadsafe version
  # @return [Milemarker] self
  def threadsafify!
    @mutex = Mutex.new
    define_singleton_method(:increment_and_on_batch) do |&blk|
      threadsafe_increment_and_on_batch(&blk)
    end
    self
  end

  # Increment the counter -- how many records processed, e.g.
  # @return [Milemarker] self
  def incr(increase = 1)
    @count += increase
    self
  end

  # Create a logger for use in logging milemaker information
  # @return [Milemarker] self
  def create_logger!(*args, **kwargs)
    @logger = Logger.new(*args, **kwargs)
    self
  end

  # Run the given block if we've exceeded the batch size for the current batch
  # @yield [Milemarker] self
  def on_batch
    if batch_size_exceeded?
      set_milemarker!
      yield self
    end
  end

  # Single call to increment and run (if needed) the on_batch block
  def _increment_and_on_batch(&blk)
    incr.on_batch(&blk)
  end

  alias_method :increment_and_on_batch, :_increment_and_on_batch

  # Threadsafe version of #increment_and_on_batch, doing the whole thing as a single atomic action
  def threadsafe_increment_and_on_batch(&blk)
    @mutex.synchronize do
      _increment_and_on_batch(&blk)
    end
  end

  # Convenience method, exactly the same as the common idiom
  #   `mm.incr; mm.on_batch {|mm| log.info mm.batch_line}`
  # @param [Symbol] level The level to log at
  def increment_and_log_batch_line(level: :info)
    increment_and_on_batch { log_batch_line(level: level) }
  end

  # Log the batch line, as described in #batch_line
  # @param [Symbol] level The level to log at
  def log_batch_line(level: :info)
    on_batch { log(batch_line, level: level) }
  end

  # Log the final line, as described in #final_line
  # @param [Symbol] level The level to log at
  def log_final_line(level: info)
    log(final_line, level: level)
  end

  # A line describing the batch suitable for logging, of the form
  #   load records.ndj   8_000_000. This batch 2_000_000 in 26.2s (76_469 r/s). Overall 72_705 r/s.
  # @return [String] The batch log line
  def batch_line
    # rubocop:disable Layout/LineLength
    "#{name} #{ppnum(count, 10)}. This batch #{ppnum(last_batch_size, 5)} in #{ppnum(last_batch_seconds, 4, 1)}s (#{batch_rate_str} r/s). Overall #{total_rate_str} r/s."
    # rubocop:enable Layout/LineLength
  end

  # A line describing the entire run, suitable for logging, of the form
  #   load records.ndj FINISHED. 27_138_118 total records in 00h 12m 39s. Overall 35_718 r/s.
  # @return [String] The full log line
  def final_line
    # rubocop:disable Layout/LineLength
    "#{name} FINISHED. #{ppnum(count, 10)} total records in #{seconds_to_time_string(total_seconds_so_far)}. Overall #{total_rate_str} r/s."
    # rubocop:enable Layout/LineLength
  end

  # @param [Integer] decimals Number of decimal places to the right of the
  #   decimal point
  # @return [String] Rate-per-second in form XXX.YY
  def batch_rate_str(decimals = 0)
    return "0" if @count.zero?
    ppnum(last_batch_size.to_f / last_batch_seconds, 0, decimals)
  end

  # @param [Integer] decimals Number of decimal places to the right of the
  #   decimal point
  # @return [String] Rate-per-second in form XXX.YY
  def total_rate_str(decimals = 0)
    return "0" if @count.zero?
    ppnum(count / total_seconds_so_far, 0, decimals)
  end

  # Total seconds since the beginning of this milemarker
  # @return [Numeric] seconds since the milemarker was created
  def total_seconds_so_far
    Time.now - start_time
  end

  # Total seconds since this batch started
  # @return [Numeric] seconds since the beginning of this batch
  def batch_seconds_so_far
    Time.now = batch_start_time
  end

  # Set/reset all the internal state. Called by #on_batch when necessary;
  # should probably not be called manually
  def set_milemarker!
    @batch_end_time     = Time.now
    @last_batch_size    = @count - @prev_count
    @last_batch_seconds = @batch_end_time - @batch_start_time

    reset_for_next_batch!
  end

  # Reset the internal counters/timers at the end of a batch. Taken care of
  # by #on_batch; should probably not be called manually.
  def reset_for_next_batch!
    @batch_start_time  = batch_end_time
    @prev_count        = count
    @batch_number = batch_divisor
  end


  # Log a line using the internal logger. Do nothing if no logger is configured.
  # @param [String] msg The message to log
  # @param [Symbol] level The level to log at
  def log(msg, level: :info)
    if logger
      logger.send(level, msg)
    end
  end



  private

  def batch_size_exceeded?
    batch_divisor > @batch_number
  end

  def batch_divisor
    count.div batch_size
  end

  def seconds_to_time_string(sec)
    hours, leftover = sec.divmod(3600)
    minutes, secs   = leftover.divmod(60)
    format("%02dh %02dm %02ds", hours, minutes, secs)
  end
end


