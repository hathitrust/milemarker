# frozen_string_literal: true
require

class Milemarker
  class Structured < Milemarker

  def create_logger!(*args, **kwargs)
    super
    @logger.formatter = proc do |severity, datetime, progname, msg|
      case msg
        when Hash
          msg
        when String
          {msg: msg}
        when Exception
          {msg: msg.message, error: msg.class, at: msg.backtrace&.first, hostname: Socket.gethostname}
        else
          if msg.respond_to? :to_h
            msg.to_h
          else
            {msg: msg.inspect}
          end
      end.merge({level: severity, time: datetime}).to_json
    end
  end

  def batch_line
    {
      name: name,
      batch_count: last_batch_size,
      batch_seconds: last_batch_seconds,
      batch_rate: count.zero? ? 0 : last_batch_size.to_f / last_batch_seconds,
      total_count: count,
      total_seconds: total_seconds_so_far,
      total_rate: count.zero? ? 0 : count.to_f / total_seconds_so_far
    }
  end

  alias_method :batch_data, :batch_line

  def final_line
    {
      name: name,
      total_count: count,
      total_seconds: total_seconds_so_far,
      total_rate: count.zero? ? 0 : count.to_f / total_seconds_so_far
    }
  end

  alias_method :final_data, :final_line

end
end
