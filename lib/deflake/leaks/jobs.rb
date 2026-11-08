# frozen_string_literal: true

module Deflake
  module Leaks
    # Jobs left in the ActiveJob test queue
    class Jobs
      # Ids of the enqueued jobs: ActiveJob::TestHelper empties the queue before
      # every test, so comparing sizes would miss a job left after another one
      def snapshot
        return unless defined?(::ActiveJob) && Leaks.loaded?(::ActiveJob, :Base)

        # Not queue_adapter: when no adapter is set, it sets :async, which would
        # stop ActiveJob::TestHelper from installing its test adapter
        adapter = ::ActiveJob::Base._queue_adapter
        adapter.enqueued_jobs.map(&:object_id) if adapter.respond_to?(:enqueued_jobs)
      end

      def diff(before, after)
        added = (after - before).size
        return [] unless added.positive?

        ["#{added} enqueued #{added == 1 ? "job" : "jobs"} left in the ActiveJob queue"]
      end
    end
  end
end
