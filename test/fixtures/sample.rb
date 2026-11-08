# frozen_string_literal: true

require "minitest/autorun"

# A tiny suite for testing deflake: every kind of outcome, each one stable
class SampleTest < Minitest::Test
  def test_passes
    assert true
  end

  def test_fails
    assert_equal 2, 1
  end

  def test_raises
    raise "boom"
  end

  def test_skipped
    skip "not ready"
  end
end
