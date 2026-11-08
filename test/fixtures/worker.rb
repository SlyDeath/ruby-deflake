# frozen_string_literal: true

require "minitest/autorun"

# Fails with the number of the deflake worker that ran it
class WorkerTest < Minitest::Test
  def test_reports_worker
    flunk "worker #{ENV.fetch("TEST_ENV_NUMBER", "none").inspect}"
  end
end
