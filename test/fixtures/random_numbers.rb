# frozen_string_literal: true

require "minitest/autorun"

# Each test tells the random number it got, which depends on the seed and on what ran before it
class FirstRandomTest < Minitest::Test
  def test_draws
    flunk "drew #{rand(1_000_000)}"
  end
end

class SecondRandomTest < Minitest::Test
  def test_draws
    flunk "drew #{rand(1_000_000)}"
  end

  def test_other
    assert true
  end
end
