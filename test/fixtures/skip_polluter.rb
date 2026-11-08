# frozen_string_literal: true

require "minitest/autorun"

# The polluter is skipped, but only after it changed global state
$skip_polluted = false

class SkipPolluterTest < Minitest::Test
  def test_pollutes_then_skips
    $skip_polluted = true
    skip "later"
  end

  def test_fine
    assert true
  end

  def test_victim
    refute $skip_polluted
  end
end
