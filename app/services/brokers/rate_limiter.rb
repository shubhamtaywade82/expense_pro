module Brokers
  class RateLimiter
    class RateLimitExceeded < StandardError; end

    def initialize(broker_key:, max_requests:, period: 1.second)
      @broker_key = broker_key
      @max_requests = max_requests
      @period = period
      @mutex = Mutex.new
    end

    def throttle!
      @mutex.synchronize do
        now = Time.current.to_f
        window_start = now - @period

        @timestamps ||= []
        @timestamps.reject! { |t| t < window_start }

        if @timestamps.size >= @max_requests
          wait = @timestamps.first + @period - now
          sleep(wait) if wait > 0
          @timestamps.reject! { |t| t < Time.current.to_f - @period }
        end

        @timestamps << Time.current.to_f
      end
    end

    def reset!
      @mutex.synchronize do
        @timestamps = []
      end
    end
  end
end
