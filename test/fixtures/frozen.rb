# frozen_string_literal: true

require "minitest/autorun"

# One test freezes the clock at "now" and never unfreezes it; the slow test is innocent
class FrozenTest < Minitest::Test
  # The slow test must run after the freeze, or the test of deflake checks nothing
  i_suck_and_my_tests_are_order_dependent!

  def test_freezes_time
    now = Time.now
    Time.singleton_class.prepend(Module.new { define_method(:now) { now } })
  end

  def test_slow
    sleep 1.2
  end
end
