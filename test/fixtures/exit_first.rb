# frozen_string_literal: true

require "minitest/autorun"

# The first test takes the process down, so the second one never runs
class ExitFirstTest < Minitest::Test
  i_suck_and_my_tests_are_order_dependent!

  def test_a_exits
    exit!(1)
  end

  def test_b_never_runs
    flunk "ran"
  end
end
