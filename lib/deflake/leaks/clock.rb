# frozen_string_literal: true

module Deflake
  module Leaks
    # Time.now frozen or moved away from the real clock: travel_to, freeze_time or Timecop left on
    class Clock
      # Seconds Time.now may be off without being a leak: the real clock moves while it is read
      TOLERANCE = 1
      # How long to watch Time.now to tell whether it moves
      TICK = 0.0001
      # The wait for the clock to move must end whatever happens
      CHECKS = 100_000
      # Taken when deflake loads, before the tests: Timecop's mock_process_clock replaces
      # Process.clock_gettime, and the real clock would move with the mocked one
      CLOCK = Process.method(:clock_gettime)

      # [offset from the real clock in seconds, whether Time.now stands still]
      def snapshot
        first = now
        start = real
        CHECKS.times { break if real - start >= TICK }
        [first.to_f - start, now == first]
      end

      # Where the clock ends up counts: a test that brings back a clock another test moved
      # leaves nothing behind, and one that moves it says how far from the real clock it is
      def diff(before, after)
        (offset_before, frozen_before), (offset_after, frozen_after) = before, after
        return [] if frozen_before
        if frozen_after
          # Without the offset, which grows with every second the clock stands still
          return ["Time.now is frozen (freeze_time or travel_to without travel_back?)"]
        end
        return [] if (offset_after - offset_before).abs < TOLERANCE || offset_after.abs < TOLERANCE

        ["Time.now is#{shift(offset_after)} (travel_to without travel_back?)"]
      end

      private

      def now = ::Time.now
      def real = CLOCK.call(Process::CLOCK_REALTIME)

      def shift(seconds)
        return "" if seconds.abs < TOLERANCE

        " #{duration(seconds.abs)} #{seconds.positive? ? "ahead of" : "behind"} the real clock"
      end

      # In whole seconds, so a day measured a moment early is still a day
      def duration(seconds)
        seconds = seconds.round
        [[86_400, "day"], [3600, "hour"], [60, "minute"], [1, "second"]].each do |size, unit|
          count = seconds.fdiv(size).round
          return "#{count} #{unit}#{"s" unless count == 1}" if count.positive? && seconds >= size
        end
      end
    end
  end
end
