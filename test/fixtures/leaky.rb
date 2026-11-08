# frozen_string_literal: true

require "minitest/autorun"

# Every test except the last one leaves some global state behind
class LeakyTest < Minitest::Test
  def test_sets_env
    ENV["DEFLAKE_FIXTURE_LEAK"] = "1"
  end

  def test_travels_in_time
    three_days = 3 * 24 * 60 * 60
    Time.singleton_class.prepend(Module.new { define_method(:now) { super() + three_days } })
  end

  def test_sets_global
    $deflake_fixture_leak = true
  end

  def test_cleans_up
    ENV["DEFLAKE_FIXTURE_TEMP"] = "1"
  ensure
    ENV.delete("DEFLAKE_FIXTURE_TEMP")
  end
end
