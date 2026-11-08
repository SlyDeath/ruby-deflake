# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "active_job"

# ActiveJob without Rails and without a queue adapter: ActiveJob::TestHelper installs its own
ActiveJob::Base.logger = Logger.new(nil)

class NoopJob < ActiveJob::Base
  def perform; end
end

class EnqueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def test_enqueues
    assert_enqueued_jobs(1) { NoopJob.perform_later }
  end
end
