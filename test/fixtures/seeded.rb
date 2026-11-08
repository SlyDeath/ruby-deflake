# frozen_string_literal: true

require "minitest/autorun"

# The victim fails with every even seed, whatever runs before it
class SeededTest < Minitest::Test
  def test_first
    assert true
  end

  def test_victim
    assert_predicate Minitest.seed, :odd?
  end
end
