# frozen_string_literal: true

require "minitest/autorun"

# Tests that Minitest runs at once; only the first one leaks
class ParallelTest < Minitest::Test
  parallelize_me!

  def test_leaks_late
    sleep 0.3
    $deflake_fixture_parallel = true
  end

  def test_slow
    sleep 0.6
  end
end
